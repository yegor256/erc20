# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

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
  # Address of USDT contract.
  USDT = '0xdac17f958d2ee523a2206206994597c13d831ec7'

  # These properties are read-only:
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
  # @param [Object] log The destination for logs
  def initialize(contract: USDT, chain: 1, log: $stdout,
                 host: nil, port: 443, http_path: '/', ws_path: '/',
                 ssl: true, proxy: nil)
    raise 'Contract can\'t be nil' unless contract
    raise 'Contract must be a String' unless contract.is_a?(String)
    raise 'Invalid format of the contract' unless /^0x[0-9a-fA-F]{40}$/.match?(contract)
    @contract = contract
    raise 'Host can\'t be nil' unless host
    raise 'Host must be a String' unless host.is_a?(String)
    @host = host
    raise 'Port can\'t be nil' unless port
    raise 'Port must be an Integer' unless port.is_a?(Integer)
    raise 'Port must be a positive Integer' unless port.positive?
    @port = port
    raise 'Ssl can\'t be nil' if ssl.nil?
    @ssl = ssl
    raise 'Http_path can\'t be nil' unless http_path
    raise 'Http_path must be a String' unless http_path.is_a?(String)
    @http_path = http_path
    raise 'Ws_path can\'t be nil' unless ws_path
    raise 'Ws_path must be a String' unless ws_path.is_a?(String)
    @ws_path = ws_path
    raise 'Log can\'t be nil' unless log
    @log = log
    raise 'Chain can\'t be nil' unless chain
    raise 'Chain must be an Integer' unless chain.is_a?(Integer)
    raise 'Chain must be a positive Integer' unless chain.positive?
    @chain = chain
    @proxy = proxy
    @mutex = Mutex.new
  end

  # Get ERC20 balance of a public address (it's not the same as ETH balance!).
  #
  # An address in Ethereum may have many balances. One of them is the main
  # balance in ETH crypto. Another balance is the one kept by the ERC20 contract
  # in its own ledger in root storage. This balance is checked by this method.
  #
  # @param [String] address Public key, in hex, starting from '0x'
  # @return [Integer] Balance, in tokens
  def balance(address)
    raise 'Address can\'t be nil' unless address
    raise 'Address must be a String' unless address.is_a?(String)
    raise 'Invalid format of the address' unless /^0x[0-9a-fA-F]{40}$/.match?(address)
    func = '70a08231' # balanceOf
    data = "0x#{func}000000000000000000000000#{address[2..].downcase}"
    r = jsonrpc.eth_call({ to: @contract, data: data }, 'latest')
    b = r[2..].to_i(16)
    log_it(:debug, "The balance of #{address} is #{b} ERC20 tokens")
    b
  end

  # Get ETH balance of a public address.
  #
  # An address in Ethereum may have many balances. One of them is the main
  # balance in ETH crypto. This balance is checked by this method.
  #
  # @param [String] hex Public key, in hex, starting from '0x'
  # @return [Integer] Balance, in ETH
  def eth_balance(address)
    raise 'Address can\'t be nil' unless address
    raise 'Address must be a String' unless address.is_a?(String)
    raise 'Invalid format of the address' unless /^0x[0-9a-fA-F]{40}$/.match?(address)
    r = jsonrpc.eth_getBalance(address, 'latest')
    b = r[2..].to_i(16)
    log_it(:debug, "The balance of #{address} is #{b} ETHs")
    b
  end

  # Get ERC20 amount (in tokens) that was sent in the given transaction.
  #
  # @param [String] txn Hex of transaction
  # @return [Integer] Balance, in ERC20 tokens
  def sum_of(txn)
    raise 'Transaction hash can\'t be nil' unless txn
    raise 'Transaction hash must be a String' unless txn.is_a?(String)
    raise 'Invalid format of the transaction hash' unless /^0x[0-9a-fA-F]{64}$/.match?(txn)
    receipt = jsonrpc.eth_getTransactionReceipt(txn)
    raise "Transaction not found: #{txn}" if receipt.nil?
    logs = receipt['logs'] || []
    transfer_event = '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef'
    logs.each do |log|
      next unless log['topics'] && log['topics'][0] == transfer_event
      next unless log['address'].downcase == @contract.downcase
      amount = log['data'].to_i(16)
      log_it(:debug, "Found transfer of #{amount} tokens in transaction #{txn}")
      return amount
    end
    raise "No transfer event found in transaction #{txn}"
  end

  # How many gas units are required to send an ERC20 transaction.
  #
  # @param [String] from The sending address, in hex
  # @param [String] to The receiving address, in hex
  # @param [Integer] amount How many ERC20 tokens to send
  # @return [Integer] Number of gas units required
  def gas_estimate(from, to, amount)
    raise 'Address can\'t be nil' unless from
    raise 'Address must be a String' unless from.is_a?(String)
    raise 'Invalid format of the address' unless /^0x[0-9a-fA-F]{40}$/.match?(from)
    raise 'Address can\'t be nil' unless to
    raise 'Address must be a String' unless to.is_a?(String)
    raise 'Invalid format of the address' unless /^0x[0-9a-fA-F]{40}$/.match?(to)
    raise 'Amount can\'t be nil' unless amount
    raise "Amount (#{amount}) must be an Integer" unless amount.is_a?(Integer)
    raise "Amount (#{amount}) must be a positive Integer" unless amount.positive?
    gas = jsonrpc.eth_estimateGas({ from:, to: @contract, data: to_pay_data(to, amount) }, 'latest').to_i(16)
    log_it(:debug, "It would take #{gas} gas units to send #{amount} tokens from #{from} to #{to}")
    gas
  end

  # What is the price of gas unit in gwei?
  #
  # In Ethereum, gas is a unit that measures the computational work required to
  # execute operations on the network. Every transaction and smart contract
  # interaction consumes gas. Gas price is the amount of ETH you're willing to pay
  # for each unit of gas, denominated in gwei (1 gwei = 0.000000001 ETH). Higher
  # gas prices incentivize miners to include your transaction sooner, while lower
  # prices may result in longer confirmation times.
  #
  # @return [Integer] Price of gas unit, in gwei (0.000000001 ETH)
  def gas_price
    block = jsonrpc.eth_getBlockByNumber('latest', false)
    raise "Can't get gas price, try again later" if block.nil?
    gwei = block['baseFeePerGas'].to_i(16)
    log_it(:debug, "The cost of one gas unit is #{gwei} gwei")
    gwei
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
  # @param [String] priv Private key, in hex
  # @param [String] address Public key, in hex
  # @param [Integer] amount The amount of ERC20 tokens to send
  # @param [Integer] limit How much gas you're ready to spend
  # @param [Integer] price How much gas you pay per computation unit
  # @return [String] Transaction hash
  def pay(priv, address, amount, limit: nil, price: gas_price)
    raise 'Private key can\'t be nil' unless priv
    raise 'Private key must be a String' unless priv.is_a?(String)
    raise 'Invalid format of private key' unless /^[0-9a-fA-F]{64}$/.match?(priv)
    raise 'Address can\'t be nil' unless address
    raise 'Address must be a String' unless address.is_a?(String)
    raise 'Invalid format of the address' unless /^0x[0-9a-fA-F]{40}$/.match?(address)
    raise 'Amount can\'t be nil' unless amount
    raise "Amount (#{amount}) must be an Integer" unless amount.is_a?(Integer)
    raise "Amount (#{amount}) must be a positive Integer" unless amount.positive?
    if limit
      raise 'Gas limit must be an Integer' unless limit.is_a?(Integer)
      raise 'Gas limit must be a positive Integer' unless limit.positive?
    end
    if price
      raise 'Gas price must be an Integer' unless price.is_a?(Integer)
      raise 'Gas price must be a positive Integer' unless price.positive?
    end
    key = Eth::Key.new(priv: priv)
    from = key.address.to_s
    tnx =
      @mutex.synchronize do
        nonce = jsonrpc.eth_getTransactionCount(from, 'pending').to_i(16)
        tx = Eth::Tx.new(
          {
            nonce:,
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
        jsonrpc.eth_sendRawTransaction(hex)
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
    raise 'Private key can\'t be nil' unless priv
    raise 'Private key must be a String' unless priv.is_a?(String)
    raise 'Invalid format of private key' unless /^[0-9a-fA-F]{64}$/.match?(priv)
    raise 'Address can\'t be nil' unless address
    raise 'Address must be a String' unless address.is_a?(String)
    raise 'Invalid format of the address' unless /^0x[0-9a-fA-F]{40}$/.match?(address)
    raise 'Amount can\'t be nil' unless amount
    raise "Amount (#{amount}) must be an Integer" unless amount.is_a?(Integer)
    raise "Amount (#{amount}) must be a positive Integer" unless amount.positive?
    if price
      raise 'Gas price must be an Integer' unless price.is_a?(Integer)
      raise 'Gas price must be a positive Integer' unless price.positive?
    end
    key = Eth::Key.new(priv: priv)
    from = key.address.to_s
    tnx =
      @mutex.synchronize do
        nonce = jsonrpc.eth_getTransactionCount(from, 'pending').to_i(16)
        tx = Eth::Tx.new(
          {
            chain_id: @chain,
            nonce:,
            gas_price: price,
            gas_limit: 22_000,
            to: address,
            value: amount
          }
        )
        tx.sign(key)
        hex = "0x#{tx.hex}"
        jsonrpc.eth_sendRawTransaction(hex)
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
  # The +active+ must have +append()+ and +to_a()+ implemented. This array
  # maintains the list of addresses that were mentioned in incoming transactions.
  # This array is used mostly for testing. It is suggested to always provide
  # an empty array.
  #
  # @param [Array<String>] addresses Addresses to monitor
  # @param [Array] active List of addresses that we are actually listening to
  # @param [Boolean] raw TRUE if you need to get JSON events as they arrive from Websockets
  # @param [Integer] delay How many seconds to wait between +eth_subscribe+ calls
  # @param [Integer] subscription_id Unique ID of the subscription
  def accept(addresses, active = [], raw: false, delay: 1, subscription_id: rand(99_999), &)
    raise 'Addresses can\'t be nil' unless addresses
    raise 'Addresses must respond to .to_a()' unless addresses.respond_to?(:to_a)
    raise 'Active can\'t be nil' unless active
    raise 'Active must respond to .to_a()' unless active.respond_to?(:to_a)
    raise 'Active must respond to .append()' unless active.respond_to?(:append)
    raise 'Active must respond to .clear()' unless active.respond_to?(:clear)
    raise 'Delay must be an Integer' unless delay.is_a?(Integer)
    raise 'Delay must be a positive Integer or positive Float' unless delay.positive?
    raise 'Subscription ID must be an Integer' unless subscription_id.is_a?(Integer)
    raise 'Subscription ID must be a positive Integer' unless subscription_id.positive?
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
  # @return [Websocket]
  def reaccept(addresses, active, raw:, delay:, subscription_id:, &)
    u = url(http: false)
    log_it(:debug, "Connecting ##{subscription_id} to #{u.hostname}:#{u.port}...")
    contract = @contract
    log_url = "ws#{'s' if @ssl}://#{u.hostname}:#{u.port}"
    ws = Faye::WebSocket::Client.new(u.to_s, [], proxy: @proxy ? { origin: @proxy } : {}, ping: 60)
    timer = nil
    ws.on(:open) do
      safe do
        verbose do
          log_it(:debug, "Connected ##{subscription_id} to #{log_url}")
          timer =
            EventMachine.add_periodic_timer(delay) do
              next if active.to_a.sort == addresses.to_a.sort
              ws.send(
                {
                  jsonrpc: '2.0',
                  id: subscription_id,
                  method: 'eth_subscribe',
                  params: [
                    'logs',
                    {
                      address: contract,
                      topics: [
                        '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef',
                        nil,
                        addresses.to_a.map { |a| "0x000000000000000000000000#{a[2..]}" }
                      ]
                    }
                  ]
                }.to_json
              )
              log_it(
                :debug,
                "Requested to subscribe ##{subscription_id} to #{addresses.to_a.size} addresses: " \
                "#{addresses.to_a.map { |a| a[0..6] }.join(', ')}"
              )
            end
        end
      end
    end
    ws.on(:message) do |msg|
      safe do
        verbose do
          data = to_json(msg)
          if data['id']
            before = active.to_a.uniq
            addresses.to_a.each do |a|
              next if before.include?(a)
              active.append(a)
            end
            log_it(
              :debug,
              "Subscribed ##{subscription_id} to #{active.to_a.size} addresses at #{log_url}: " \
              "#{active.to_a.map { |a| a[0..6] }.join(', ')}"
            )
          elsif data['method'] == 'eth_subscription' && data.dig('params', 'result')
            event = data['params']['result']
            if raw
              log_it(:debug, "New event arrived from #{event['address']}")
            else
              event = {
                amount: event['data'].to_i(16),
                from: "0x#{event['topics'][1][26..].downcase}",
                to: "0x#{event['topics'][2][26..].downcase}",
                txn: event['transactionHash'].downcase
              }
              log_it(
                :debug,
                "Payment of #{event[:amount]} tokens arrived at ##{subscription_id} " \
                "from #{event[:from]} to #{event[:to]} in #{event[:txn]}"
              )
            end
            yield event
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
          reaccept(addresses, active, raw:, delay:, subscription_id: subscription_id + 1, &)
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

  def to_json(msg)
    JSON.parse(msg.data)
  rescue StandardError
    {}
  end

  def verbose
    yield
  rescue StandardError => e
    log_it(:error, Backtrace.new(e).to_s)
    raise e
  end

  def safe
    yield
  rescue StandardError
    # ignore it
  end

  def url(http: true)
    URI.parse("#{http ? 'http' : 'ws'}#{'s' if @ssl}://#{@host}:#{@port}#{http ? @http_path : @ws_path}")
  end

  def jsonrpc
    JSONRPC.logger = Loog::NULL
    opts = {}
    if @proxy
      uri = URI.parse(@proxy)
      opts[:connection] =
        Faraday.new do |f|
          f.adapter(Faraday.default_adapter)
          f.proxy = {
            uri: "#{uri.scheme}://#{uri.hostname}:#{uri.port}",
            user: uri.user,
            password: uri.password
          }
        end
    end
    JSONRPC::Client.new(url.to_s, opts)
  end

  def to_pay_data(address, amount)
    func = 'a9059cbb' # transfer(address,uint256)
    to_clean = address.downcase.sub(/^0x/, '')
    to_padded = ('0' * (64 - to_clean.size)) + to_clean
    amt_hex = amount.to_s(16)
    amt_padded = ('0' * (64 - amt_hex.size)) + amt_hex
    "0x#{func}#{to_padded}#{amt_padded}"
  end

  def log_it(method, msg)
    if @log.respond_to?(method)
      @log.__send__(method, msg)
    elsif @log.respond_to?(:puts)
      @log.puts(msg)
    end
  end
end
