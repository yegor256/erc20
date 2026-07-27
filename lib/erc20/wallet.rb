# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'elapsed'
require 'eth'
require 'eventmachine'
require 'faye/websocket'
require 'json'
require 'jsonrpc/client'
require 'loog'
require 'uri'
require_relative 'erc20'

# A wallet with ERC20 tokens on Ethereum.
#
# Objects of this class are thread-safe.
#
# In order to check the balance of ERC20 address:
#
#  require 'erc20'
#  w = ERC20::Wallet.new(
#    contract: ERC20::Wallet.USDT, # hex of it
#    host: 'mainnet.infura.io',
#    http_path: '/v3/<your-infura-key>',
#    ws_path: '/ws/v3/<your-infura-key>',
#    log: $stdout
#  )
#  usdt = w.balance(address)
#
# In order to send a payment:
#
#  hex = w.pay(private_key, to_address, amount)
#
# In order to catch incoming payments to a set of addresses:
#
#  addresses = ['0x...', '0x...']
#  w.accept(addresses) do |event|
#    puts event[:txt] # hash of transaction
#    puts event[:amount] # how much, in tokens (1000000 = $1 USDT)
#    puts event[:from] # who sent the payment
#    puts event[:to] # who was the receiver
#  end
#
# To connect to the server via HTTP proxy with basic authentication:
#
#  w = ERC20::Wallet.new(
#    host: 'go.getblock.io',
#    http_path: '/<your-rpc-getblock-key>',
#    ws_path: '/<your-ws-getblock-key>',
#    proxy: 'http://jeffrey:swordfish@example.com:3128' # here!
#  )
#
# More information in our README.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2025 Yegor Bugayenko
# License:: MIT
class ERC20::Wallet
  USDT = '0xdac17f958d2ee523a2206206994597c13d831ec7'
  TRANSFER = '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef'

  MAX_AMOUNT = (2**256) - 1
  private_constant :MAX_AMOUNT

  attr_reader :host, :port, :ssl, :chain, :contract, :ws_path, :http_path

  # Constructor.
  # @param [String] contract Hex of the contract in Ethereum
  # @param [Integer] chain The ID of the chain (1 for mainnet)
  # @param [String] host The host to connect to
  # @param [Integer] port TCP port to use
  # @param [String] http_path The path in the connection URL, for HTTP RPC
  # @param [String] ws_path The path in the connection URL, for Websockets
  # @param [Boolean] ssl Should we use SSL (for https and wss)
  # @param [String] proxy The URL of the proxy to use
  # @param [Integer] attempts How many times to try every HTTP RPC endpoint before giving up
  # @param [Array<String>] fallbacks Alternative HTTP RPC endpoint URLs to try when the primary one fails
  # @param [Object] log The destination for logs
  def initialize(
    contract: USDT, chain: 1, log: $stdout,
    host: nil, port: 443, http_path: '/', ws_path: '/',
    ssl: true, proxy: nil, attempts: 1, fallbacks: []
  )
    raise(ArgumentError, 'Contract can\'t be nil') unless contract
    raise(ArgumentError, 'Contract must be a String') unless contract.is_a?(String)
    raise(ArgumentError, 'Invalid format of the contract') unless /^0x[0-9a-fA-F]{40}$/.match?(contract)
    @contract = contract
    raise(ArgumentError, 'Host can\'t be nil') unless host
    raise(ArgumentError, 'Host must be a String') unless host.is_a?(String)
    @host = host
    raise(ArgumentError, 'Port can\'t be nil') unless port
    raise(ArgumentError, 'Port must be an Integer') unless port.is_a?(Integer)
    raise(ArgumentError, 'Port must be a positive Integer') unless port.positive?
    @port = port
    raise(ArgumentError, 'Ssl can\'t be nil') if ssl.nil?
    @ssl = ssl
    raise(ArgumentError, 'Http_path can\'t be nil') unless http_path
    raise(ArgumentError, 'Http_path must be a String') unless http_path.is_a?(String)
    @http_path = http_path
    raise(ArgumentError, 'Ws_path can\'t be nil') unless ws_path
    raise(ArgumentError, 'Ws_path must be a String') unless ws_path.is_a?(String)
    @ws_path = ws_path
    raise(ArgumentError, 'Log can\'t be nil') unless log
    @log = log
    raise(ArgumentError, 'Chain can\'t be nil') unless chain
    raise(ArgumentError, 'Chain must be an Integer') unless chain.is_a?(Integer)
    raise(ArgumentError, 'Chain must be a positive Integer') unless chain.positive?
    @chain = chain
    @proxy = proxy
    raise(ArgumentError, 'Attempts can\'t be nil') unless attempts
    raise(ArgumentError, 'Attempts must be an Integer') unless attempts.is_a?(Integer)
    raise(ArgumentError, 'Attempts must be a positive Integer') unless attempts.positive?
    @attempts = attempts
    raise(ArgumentError, 'Fallbacks can\'t be nil') if fallbacks.nil?
    raise(ArgumentError, 'Fallbacks must be an Array') unless fallbacks.is_a?(Array)
    fallbacks.each do |f|
      raise(ArgumentError, 'Each fallback must be a String') unless f.is_a?(String)
    end
    @fallbacks = fallbacks
    @mutex = Mutex.new
  end

  # Get ERC20 balance of a public address (it's not the same as ETH balance!).
  #
  # An address in Ethereum may have many balances. One of them is the main
  # balance in ETH crypto. Another balance is the one kept by the ERC20 contract
  # in its own ledger in root storage. This balance is checked by this method.
  #
  # An address that has no tokens has a balance of zero, but so does an address
  # asked at the wrong contract or in the wrong chain: there, +eth_call+ succeeds
  # with empty return data. A +balanceOf+ always answers with a single 32-byte
  # word, thus anything shorter is a misconfiguration and an error is raised,
  # instead of a zero that nobody may tell from a genuinely empty balance.
  #
  # @param [String] address Public key, in hex, starting from '0x'
  # @return [Integer] Balance, in tokens
  def balance(address)
    raise(ArgumentError, 'Address can\'t be nil') unless address
    raise(ArgumentError, 'Address must be a String') unless address.is_a?(String)
    raise(ArgumentError, 'Invalid format of the address') unless /^0x[0-9a-fA-F]{40}$/.match?(address)
    data = "0x70a08231000000000000000000000000#{address[2..].downcase}"
    hex = with_jsonrpc { |jr| jr.eth_call({ to: @contract, data: data }, 'latest') }
    unless /^0x[0-9a-fA-F]{64}$/.match?(hex)
      raise(
        StandardError,
        "The #{@contract} contract in chain #{@chain} answered #{hex.inspect} instead of " \
        'a 32-byte word, it may not be an ERC20 contract at all'
      )
    end
    b = hex[2..].to_i(16)
    log_it(:debug, "The balance of #{address} is #{b} ERC20 tokens")
    b
  end

  # Get ETH balance of a public address.
  #
  # An address in Ethereum may have many balances. One of them is the main
  # balance in ETH crypto. This balance is checked by this method.
  #
  # @param [String] address Public key, in hex, starting from '0x'
  # @return [Integer] Balance, in ETH
  def eth_balance(address)
    raise(ArgumentError, 'Address can\'t be nil') unless address
    raise(ArgumentError, 'Address must be a String') unless address.is_a?(String)
    raise(ArgumentError, 'Invalid format of the address') unless /^0x[0-9a-fA-F]{40}$/.match?(address)
    hex = with_jsonrpc { |jr| jr.eth_getBalance(address, 'latest') }
    unless /^0x[0-9a-fA-F]+$/.match?(hex)
      raise(StandardError, "The node answered #{hex.inspect} instead of a hex quantity, for the balance of #{address}")
    end
    b = hex[2..].to_i(16)
    log_it(:debug, "The balance of #{address} is #{b} ETHs")
    b
  end

  # Get ERC20 amount (in tokens) that was sent in the given transaction.
  #
  # One transaction may carry many transfers of the same token: batch payouts,
  # multisend contracts, swaps, and fee splits all do that. When the +to+ is
  # given, only the transfers to that address are counted and their sum is
  # returned. When it is not given and the transaction carries more than one
  # transfer, the amount is ambiguous and an error is raised.
  #
  # @param [String] txn Hex of transaction
  # @param [String] to Public key of the receiver, in hex, starting from '0x'
  # @return [Integer] Amount, in ERC20 tokens
  def sum_of(txn, to: nil)
    raise(ArgumentError, 'Transaction hash can\'t be nil') unless txn
    raise(ArgumentError, 'Transaction hash must be a String') unless txn.is_a?(String)
    raise(ArgumentError, 'Invalid format of the transaction hash') unless /^0x[0-9a-fA-F]{64}$/.match?(txn)
    unless to.nil?
      raise(ArgumentError, 'Address must be a String') unless to.is_a?(String)
      raise(ArgumentError, 'Invalid format of the address') unless /^0x[0-9a-fA-F]{40}$/.match?(to)
    end
    receipt =
      with_jsonrpc do |jr|
        jr.eth_getTransactionReceipt(txn)
      end
    raise(StandardError, "Transaction not found: #{txn}") if receipt.nil?
    raise(StandardError, "Transaction #{txn} is reverted, its status is #{receipt['status']}") \
      unless receipt['status'] == '0x1'
    amounts =
      (receipt['logs'] || []).filter_map do |log|
        next unless log['topics'] && log['topics'][0] == TRANSFER
        next unless log['address'].downcase == @contract.downcase
        next unless to.nil? || log['topics'][2].to_s.downcase == "0x000000000000000000000000#{to[2..].downcase}"
        log['data'].to_i(16)
      end
    raise(StandardError, "No transfer event found in transaction #{txn}") if amounts.empty?
    if to.nil? && amounts.size > 1
      raise(
        StandardError,
        "Transaction #{txn} carries #{amounts.size} transfers, tell me the receiving address to pick the right ones"
      )
    end
    sum = amounts.sum
    log_it(:debug, "Found transfer of #{sum} tokens in transaction #{txn}")
    sum
  end

  # How many gas units are required to send an ERC20 transaction.
  #
  # @param [String] from The sending address, in hex
  # @param [String] to The receiving address, in hex
  # @param [Integer] amount How many ERC20 tokens to send
  # @return [Integer] Number of gas units required
  def gas_estimate(from, to, amount)
    raise(ArgumentError, 'Address can\'t be nil') unless from
    raise(ArgumentError, 'Address must be a String') unless from.is_a?(String)
    raise(ArgumentError, 'Invalid format of the address') unless /^0x[0-9a-fA-F]{40}$/.match?(from)
    raise(ArgumentError, 'Address can\'t be nil') unless to
    raise(ArgumentError, 'Address must be a String') unless to.is_a?(String)
    raise(ArgumentError, 'Invalid format of the address') unless /^0x[0-9a-fA-F]{40}$/.match?(to)
    raise(ArgumentError, 'Amount can\'t be nil') unless amount
    raise(ArgumentError, "Amount (#{amount}) must be an Integer") unless amount.is_a?(Integer)
    raise(ArgumentError, "Amount (#{amount}) must be a positive Integer") unless amount.positive?
    raise(ArgumentError, "Amount (#{amount}) must fit into uint256") if amount > MAX_AMOUNT
    gas =
      with_jsonrpc do |jr|
        jr.eth_estimateGas({ from:, to: @contract, data: to_pay_data(to, amount) }, 'latest').to_i(16)
      end
    log_it(:debug, "It would take #{gas} gas units to send #{amount} tokens from #{from} to #{to}")
    gas
  end

  GAS_PRICE_TIP = 1_000_000_000

  # What is the price of gas unit in wei?
  #
  # In Ethereum, gas is a unit that measures the computational work required to
  # execute operations on the network. Every transaction and smart contract
  # interaction consumes gas. Gas price is the amount of ETH you're willing to pay
  # for each unit of gas, denominated in wei (1 gwei = 0.000000001 ETH). Higher
  # gas prices incentivize miners to include your transaction sooner, while lower
  # prices may result in longer confirmation times.
  #
  # The returned price is not the bare EIP-1559 base fee. The base fee alone
  # leaves a zero miner tip (+tip = gasPrice - baseFee = 0+), so proposers have
  # no incentive to include the transaction, and it becomes unmineable the
  # moment the base fee rises (it may grow up to 12.5% per block). To make the
  # price mineable, we double the base fee (a buffer that absorbs several blocks
  # of base-fee growth) and add a priority tip (+GAS_PRICE_TIP+).
  #
  # @return [Integer] Price of gas unit, in wei (1 gwei = 0.000000001 ETH)
  def gas_price
    block =
      with_jsonrpc do |jr|
        jr.eth_getBlockByNumber('latest', false)
      end
    raise(StandardError, "Can't get gas price, try again later") if block.nil?
    base = block['baseFeePerGas'].to_i(16)
    price = (base * 2) + GAS_PRICE_TIP
    log_it(:debug, "The base fee is #{base} wei, the cost of one gas unit is #{price} wei")
    price
  end

  # Send a single ERC20 payment from a private address to a public one.
  #
  # ERC20 payments differ fundamentally from native ETH transfers. While ETH transfers
  # simply move the cryptocurrency directly between addresses, ERC20 token transfers
  # are actually interactions with a smart contract. When you transfer ERC20 tokens,
  # you're not sending anything directly to another user - instead, you're calling
  # the token contract's transfer function, which updates its internal ledger to
  # decrease your balance and increase the recipient's balance. This requires more
  # gas than ETH transfers since it involves executing contract code.
  #
  # The nonce is fetched and the transaction is signed before the broadcast,
  # outside of the retry loop. A broadcast that fails is repeated with the very
  # same signed transaction, which the network either mines once or rejects as
  # already known. Thus, no number of +attempts+ may pay twice.
  #
  # @param [String] priv Private key, in hex
  # @param [String] address Public key, in hex
  # @param [Integer] amount The amount of ERC20 tokens to send
  # @param [Integer] limit How much gas you're ready to spend
  # @param [Integer] price How much gas you pay per computation unit
  # @return [String] Transaction hash
  def pay(priv, address, amount, limit: nil, price: gas_price)
    raise(ArgumentError, 'Private key can\'t be nil') unless priv
    raise(ArgumentError, 'Private key must be a String') unless priv.is_a?(String)
    raise(ArgumentError, 'Invalid format of private key') unless /^[0-9a-fA-F]{64}$/.match?(priv)
    raise(ArgumentError, 'Address can\'t be nil') unless address
    raise(ArgumentError, 'Address must be a String') unless address.is_a?(String)
    raise(ArgumentError, 'Invalid format of the address') unless /^0x[0-9a-fA-F]{40}$/.match?(address)
    raise(ArgumentError, 'Amount can\'t be nil') unless amount
    raise(ArgumentError, "Amount (#{amount}) must be an Integer") unless amount.is_a?(Integer)
    raise(ArgumentError, "Amount (#{amount}) must be a positive Integer") unless amount.positive?
    raise(ArgumentError, "Amount (#{amount}) must fit into uint256") if amount > MAX_AMOUNT
    if limit
      raise(ArgumentError, 'Gas limit must be an Integer') unless limit.is_a?(Integer)
      raise(ArgumentError, "Gas limit #{limit} is below #{Eth::Tx::DEFAULT_GAS_LIMIT}") if limit < Eth::Tx::DEFAULT_GAS_LIMIT
      raise(ArgumentError, "Gas limit #{limit} is above #{Eth::Tx::BLOCK_GAS_LIMIT}") if limit > Eth::Tx::BLOCK_GAS_LIMIT
    end
    if price
      raise(ArgumentError, 'Gas price must be an Integer') unless price.is_a?(Integer)
      raise(ArgumentError, 'Gas price must be a positive Integer') unless price.positive?
    end
    key = Eth::Key.new(priv: priv)
    from = key.address.to_s
    tnx =
      @mutex.synchronize do
        tx = Eth::Tx.new(
          {
            nonce: with_jsonrpc { |jr| jr.eth_getTransactionCount(from, 'pending').to_i(16) },
            gas_price: price,
            gas_limit: limit || gas_estimate(from, address, amount),
            to: @contract,
            value: 0,
            data: to_pay_data(address, amount),
            chain_id: @chain
          }
        )
        tx.sign(key)
        hex = "0x#{tx.hex}"
        log_it(:debug, "Sending ERC20 transaction #{hex}")
        with_jsonrpc { |jr| jr.eth_sendRawTransaction(hex) }
      end
    log_it(:debug, "Sent #{amount} ERC20 tokens from #{from} to #{address}: #{tnx}")
    tnx.downcase
  end

  # Send a single ETH payment from a private address to a public one.
  #
  # @param [String] priv Private key, in hex
  # @param [String] address Public key, in hex
  # @param [Integer] amount The amount of ETH to send
  # @param [Integer] price How much gas you pay per computation unit
  # @return [String] Transaction hash
  def eth_pay(priv, address, amount, price: gas_price)
    raise(ArgumentError, 'Private key can\'t be nil') unless priv
    raise(ArgumentError, 'Private key must be a String') unless priv.is_a?(String)
    raise(ArgumentError, 'Invalid format of private key') unless /^[0-9a-fA-F]{64}$/.match?(priv)
    raise(ArgumentError, 'Address can\'t be nil') unless address
    raise(ArgumentError, 'Address must be a String') unless address.is_a?(String)
    raise(ArgumentError, 'Invalid format of the address') unless /^0x[0-9a-fA-F]{40}$/.match?(address)
    raise(ArgumentError, 'Amount can\'t be nil') unless amount
    raise(ArgumentError, "Amount (#{amount}) must be an Integer") unless amount.is_a?(Integer)
    raise(ArgumentError, "Amount (#{amount}) must be a positive Integer") unless amount.positive?
    if price
      raise(ArgumentError, 'Gas price must be an Integer') unless price.is_a?(Integer)
      raise(ArgumentError, 'Gas price must be a positive Integer') unless price.positive?
    end
    key = Eth::Key.new(priv: priv)
    from = key.address.to_s
    tnx =
      @mutex.synchronize do
        tx = Eth::Tx.new(
          {
            chain_id: @chain,
            nonce: with_jsonrpc { |jr| jr.eth_getTransactionCount(from, 'pending').to_i(16) },
            gas_price: price,
            gas_limit: 22_000,
            to: address,
            value: amount
          }
        )
        tx.sign(key)
        hex = "0x#{tx.hex}"
        log_it(:debug, "Sending ETH transaction #{hex}")
        with_jsonrpc { |jr| jr.eth_sendRawTransaction(hex) }
      end
    log_it(:debug, "Sent #{amount} ETHs from #{from} to #{address}: #{tnx}")
    tnx.downcase
  end

  # Wait for incoming transactions and let the block know when they
  # arrive. It's a blocking call, it's better to run it in a separate
  # thread. It will never finish. In order to stop it, you should do
  # +Thread.kill+.
  #
  # The array with the list of addresses (+addresses+) may change its
  # content on-the-fly. The +accept()+ method will +eth_subscribe+ to the addresses
  # that are added and will +eth_unsubscribe+ from those that are removed.
  # Once we actually start listening, the +active+ array will be updated
  # with the list of addresses.
  #
  # The +addresses+ must have +to_a()+ implemented. This method will be
  # called every +delay+ seconds. It is expected that it returns the list
  # of Ethereum public addresses that must be monitored.
  #
  # The +active+ must have +append()+, +clear()+ and +to_a()+ implemented. This
  # array holds the addresses that the node has confirmed a subscription for,
  # and it is rebuilt on every confirmation. This array is used mostly for
  # testing. It is suggested to always provide an empty array.
  #
  # When the node answers a subscribe request with an error, the addresses stay
  # out of +active+, the error goes to the log, and the next subscribe attempt
  # happens +delay+ seconds later.
  #
  # A dropped connection leaves a gap: the blocks mined between the disconnect
  # and the confirmation of the new subscription are not streamed by the node.
  # After a reconnect, the logs of that gap are fetched with +eth_getLogs+ and
  # yielded before the live ones. A payment may arrive twice this way, because
  # the gap starts at the block of the last payment seen, and the block must be
  # ready for it: use +txn+ and +index+ of the event as the key of the payment.
  #
  # An exception from the block does not stop the stream: it goes to the log
  # and the event is gone, since the node has no way of sending it again. The
  # block must handle its own errors, if the payment must not be lost.
  #
  # A reorganization of the chain may revert a payment that was already mined.
  # The node then re-sends its log with the +removed+ flag set. Such an event
  # is not yielded, since the payment never happened. In +raw+ mode the event
  # is yielded as it arrives and the +removed+ flag must be checked by the
  # consumer.
  #
  # Events are yielded with zero confirmations, the moment they arrive from the
  # node. A payment must not be treated as settled until enough blocks are
  # mined on top of it.
  #
  # @param [Array<String>] addresses Addresses to monitor
  # @param [Array] active List of addresses that we are actually listening to
  # @param [Boolean] raw TRUE if you need to get JSON events as they arrive from Websockets
  # @param [Integer] delay How many seconds to wait between +eth_subscribe+ calls
  # @param [Integer] subscription_id Unique ID of the subscription
  def accept(addresses, active = [], raw: false, delay: 1, subscription_id: rand(99_999), &)
    raise(ArgumentError, 'Addresses can\'t be nil') unless addresses
    raise(ArgumentError, 'Addresses must respond to .to_a()') unless addresses.respond_to?(:to_a)
    raise(ArgumentError, 'Active can\'t be nil') unless active
    raise(ArgumentError, 'Active must respond to .to_a()') unless active.respond_to?(:to_a)
    raise(ArgumentError, 'Active must respond to .append()') unless active.respond_to?(:append)
    raise(ArgumentError, 'Active must respond to .clear()') unless active.respond_to?(:clear)
    raise(ArgumentError, 'Delay must be an Integer') unless delay.is_a?(Integer)
    raise(ArgumentError, 'Delay must be a positive Integer or positive Float') unless delay.positive?
    raise(ArgumentError, 'Subscription ID must be an Integer') unless subscription_id.is_a?(Integer)
    raise(ArgumentError, 'Subscription ID must be a positive Integer') unless subscription_id.positive?
    EventMachine.run do
      reaccept(addresses, active, raw:, delay:, subscription_id:, &)
    end
  end

  private

  # @param [Array<String>] addresses Addresses to monitor
  # @param [Array] active List of addresses that we are actually listening to
  # @param [Boolean] raw TRUE if you need to get JSON events as they arrive from Websockets
  # @param [Integer] delay How many seconds to wait between +eth_subscribe+ calls
  # @param [Integer] subscription_id Unique ID of the subscription
  # @param [Integer] since The number of the last block we have seen a payment in
  # @return [Websocket]
  def reaccept(addresses, active, raw:, delay:, subscription_id:, since: nil, &)
    u = url(http: false)
    log_it(:debug, "Connecting ##{subscription_id} to #{u.hostname}:#{u.port}...")
    log_url = "ws#{'s' if @ssl}://#{u.hostname}:#{u.port}"
    ws = Faye::WebSocket::Client.new(u.to_s, [], proxy: @proxy ? { origin: @proxy } : {}, ping: 60)
    timer = nil
    subscription = nil
    wanted = nil
    height = since
    ws.on(:open) do
      safe do
        verbose do
          log_it(:debug, "Connected ##{subscription_id} to #{log_url}")
          timer =
            EventMachine.add_periodic_timer(delay) do
              next if active.to_a.sort == addresses.to_a.sort
              # rubocop:disable Style/Send
              if subscription
                ws.send(
                  {
                    jsonrpc: '2.0',
                    id: subscription_id + 1,
                    method: 'eth_unsubscribe',
                    params: [subscription]
                  }.to_json
                )
                log_it(:debug, "Requested to unsubscribe ##{subscription_id} from #{subscription}")
                subscription = nil
              end
              wanted = addresses.to_a.dup
              ws.send(
                {
                  jsonrpc: '2.0',
                  id: subscription_id,
                  method: 'eth_subscribe',
                  params: ['logs', to_filter(wanted)]
                }.to_json
              )
              # rubocop:enable Style/Send
              log_it(
                :debug,
                "Requested to subscribe ##{subscription_id} to #{wanted.size} addresses: " \
                "#{wanted.map { |a| a[0..6] }.join(', ')}"
              )
            end
        end
      end
    end
    ws.on(:message) do |msg|
      safe do
        verbose do
          data = to_json(msg)
          if data['error']
            active.clear if data['id'] == subscription_id
            log_it(:error, "Request ##{data['id']} was rejected by #{log_url}: #{data['error']}")
          elsif data['id'] == subscription_id
            subscription = data['result']
            active.clear
            wanted&.each { |a| active.append(a) }
            log_it(
              :debug,
              "Subscribed ##{subscription_id} to #{active.to_a.size} addresses at #{log_url}: " \
              "#{active.to_a.map { |a| a[0..6] }.join(', ')}"
            )
            if since
              # rubocop:disable Style/Send
              ws.send(
                {
                  jsonrpc: '2.0',
                  id: subscription_id + 2,
                  method: 'eth_getLogs',
                  params: [to_filter(wanted).merge(fromBlock: format('0x%x', since + 1), toBlock: 'latest')]
                }.to_json
              )
              # rubocop:enable Style/Send
              log_it(:debug, "Requested ##{subscription_id} the logs of the blocks after ##{since}")
              since = nil
            end
          elsif data['id'] == subscription_id + 2
            log_it(:debug, "Received #{data['result'].size} logs mined while ##{subscription_id} was offline")
            data['result'].each do |log|
              height = [height, log['blockNumber'].to_s.to_i(16)].compact.max
              deliver(log, raw:, id: subscription_id, &)
            end
          elsif data['method'] == 'eth_subscription' && data.dig('params', 'result')
            height = [height, data['params']['result']['blockNumber'].to_s.to_i(16)].compact.max
            deliver(data['params']['result'], raw:, id: subscription_id, &)
          end
        end
      end
    end
    ws.on(:close) do
      safe do
        verbose do
          log_it(:debug, "Disconnected ##{subscription_id} from #{log_url}")
          active.clear
          timer&.cancel
          EventMachine.add_timer(delay) do
            reaccept(addresses, active, raw:, delay:, subscription_id: subscription_id + 1, since: height, &)
          end
        end
      end
    end
    ws.on(:error) do |e|
      safe do
        verbose do
          log_it(:debug, "Failed ##{subscription_id} at #{log_url}: #{e.message}")
        end
      end
    end
  end

  def to_filter(addresses)
    {
      address: @contract,
      topics: [
        TRANSFER,
        nil,
        addresses.to_a.map { |a| "0x000000000000000000000000#{a[2..]}" }
      ]
    }
  end

  def to_event(log)
    {
      amount: log['data'].to_i(16),
      block: log['blockNumber'].to_s.to_i(16),
      from: "0x#{log['topics'][1][26..].downcase}",
      index: log['logIndex'].to_s.to_i(16),
      to: "0x#{log['topics'][2][26..].downcase}",
      txn: log['transactionHash'].downcase
    }
  end

  def deliver(log, raw:, id:, &)
    if raw
      log_it(:debug, "New event arrived from #{log['address']}")
      digest(log, log['transactionHash'], &)
    elsif log['removed']
      log_it(:debug, "Payment in #{log['transactionHash']} is reverted by a reorganization of the chain, ignoring it")
    else
      event = to_event(log)
      log_it(
        :debug,
        "Payment of #{event[:amount]} tokens arrived at ##{id} " \
        "from #{event[:from]} to #{event[:to]} in #{event[:txn]}"
      )
      digest(event, event[:txn], &)
    end
  end

  def digest(event, txn)
    yield(event)
  rescue StandardError => e
    log_it(:error, "The block failed to process the payment in #{txn}, the event is lost (#{e.class}): #{e.message}")
  end

  def to_json(msg)
    JSON.parse(msg.data)
  rescue StandardError => e
    log_it(:error, "Failed to parse a frame of #{msg.data.to_s.length} bytes (#{e.message}): #{msg.data}")
    {}
  end

  def verbose
    yield
  rescue StandardError => e
    log_it(:error, Backtrace.new(e).to_s)
    raise(e)
  end

  def safe
    yield
  rescue StandardError
    nil
  end

  def url(http: true)
    URI.parse("#{http ? 'http' : 'ws'}#{'s' if @ssl}://#{@host}:#{@port}#{http ? @http_path : @ws_path}")
  end

  def with_jsonrpc
    JSONRPC.logger = Loog::NULL
    opts = {}
    if @proxy
      uri = URI.parse(@proxy)
      opts[:connection] =
        Faraday.new do |f|
          f.adapter(Faraday.default_adapter)
          f.proxy = { uri: "#{uri.scheme}://#{uri.hostname}:#{uri.port}", user: uri.user, password: uri.password }
        end
    end
    endpoints = [url.to_s] + @fallbacks
    budget = @attempts * endpoints.size
    tried = 0
    begin
      u = URI.parse(endpoints[tried % endpoints.size])
      tried += 1
      elapsed(@log, good: "Talked to #{u.host}:#{u.port}") do
        yield(JSONRPC::Client.new(u.to_s, opts))
      end
    rescue StandardError => e
      raise if tried >= budget
      pause = (tried % endpoints.size).zero? ? 2**((tried / endpoints.size) - 1) : 0
      log_it(:debug, "Attempt #{tried}/#{budget} to #{u.host} failed (#{e.class}), retrying in #{pause}s")
      sleep(pause)
      retry
    end
  end

  def to_pay_data(address, amount)
    "0xa9059cbb#{format('%064x', address.to_i(16))}#{format('%064x', amount)}"
  end

  def log_it(method, msg)
    if @log.respond_to?(method)
      @log.__send__(method, msg)
    elsif @log.respond_to?(:puts)
      @log.puts(msg)
    end
  end
end
