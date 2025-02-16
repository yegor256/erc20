# frozen_string_literal: true

# Copyright (c) 2025 Yegor Bugayenko
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'eth'
require 'eventmachine'
require 'faye/websocket'
require 'json'
require 'jsonrpc/client'
require 'loog'
require 'uri'
require_relative 'erc20'

# A wallet with ERC20 tokens on Etherium.
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
  # @param [String] contract Hex of the contract in Etherium
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

  # Get balance of a public address.
  #
  # @param [String] hex Public key, in hex, starting from '0x'
  # @return [Integer] Balance, in tokens
  def balance(hex)
    raise 'Address can\'t be nil' unless hex
    raise 'Address must be a String' unless hex.is_a?(String)
    raise 'Invalid format of the address' unless /^0x[0-9a-fA-F]{40}$/.match?(hex)
    func = '70a08231' # balanceOf
    data = "0x#{func}000000000000000000000000#{hex[2..].downcase}"
    r = jsonrpc.eth_call({ to: @contract, data: data }, 'latest')
    b = r[2..].to_i(16)
    @log.debug("Balance of #{hex} is #{b}")
    b
  end

  # Send a single payment from a private address to a public one.
  #
  # @param [String] priv Private key, in hex
  # @param [String] address Public key, in hex
  # @param [Integer] amount The amount of ERC20 tokens to send
  # @param [Integer] gas_limit How much gas you're ready to spend
  # @param [Integer] gas_price How much gas you pay per computation unit
  # @return [String] Transaction hash
  def pay(priv, address, amount, gas_limit: nil, gas_price: nil)
    raise 'Private key can\'t be nil' unless priv
    raise 'Private key must be a String' unless priv.is_a?(String)
    raise 'Invalid format of private key' unless /^[0-9a-fA-F]{64}$/.match?(priv)
    raise 'Address can\'t be nil' unless address
    raise 'Address must be a String' unless address.is_a?(String)
    raise 'Invalid format of the address' unless /^0x[0-9a-fA-F]{40}$/.match?(address)
    raise 'Amount can\'t be nil' unless amount
    raise 'Amount must be an Integer' unless amount.is_a?(Integer)
    raise 'Amount must be a positive Integer' unless amount.positive?
    if gas_limit
      raise 'Gas limit must be an Integer' unless gas_limit.is_a?(Integer)
      raise 'Gas limit must be a positive Integer' unless gas_limit.positive?
    end
    if gas_price
      raise 'Gas price must be an Integer' unless gas_price.is_a?(Integer)
      raise 'Gas price must be a positive Integer' unless gas_price.positive?
    end
    func = 'a9059cbb' # transfer(address,uint256)
    to_clean = address.downcase.sub(/^0x/, '')
    to_padded = ('0' * (64 - to_clean.size)) + to_clean
    amt_hex = amount.to_s(16)
    amt_padded = ('0' * (64 - amt_hex.size)) + amt_hex
    data = "0x#{func}#{to_padded}#{amt_padded}"
    key = Eth::Key.new(priv: priv)
    from = key.address
    tnx =
      @mutex.synchronize do
        nonce = jsonrpc.eth_getTransactionCount(from, 'pending').to_i(16)
        tx = Eth::Tx.new(
          {
            nonce:,
            gas_price: gas_price || gas_best_price,
            gas_limit: gas_limit || gas_estimate(from, data),
            to: @contract,
            value: 0,
            data: data,
            chain_id: @chain
          }
        )
        tx.sign(key)
        hex = "0x#{tx.hex}"
        jsonrpc.eth_sendRawTransaction(hex)
      end
    @log.debug("Sent #{amount} from #{from} to #{address}: #{tnx}")
    tnx.downcase
  end

  # Wait for incoming transactions and let the block know when they
  # arrive. It's a blocking call, it's better to run it in a separate
  # thread. It will never finish. In order to stop it, you should do
  # +Thread.kill+.
  #
  # The array with the list of addresses (+addresses+) may change its
  # content on-fly. The +accept()+ method will +eht_subscribe+ to the addresses
  # that are added and will +eth_unsubscribe+ from those that are removed.
  # Once we actually start listening, the +active+ array will be updated
  # with the list of addresses.
  #
  # The +addresses+ must have +to_a()+ implemented.
  # The +active+ must have +append()+ implemented.
  # Only these methods will be called.
  #
  # @param [Array<String>] addresses Addresses to monitor
  # @param [Array] active List of addresses that we are actually listening to
  # @param [Boolean] raw TRUE if you need to get JSON events as they arrive from Websockets
  # @param [Integer] delay How many seconds to wait between +eth_subscribe+ calls
  # @param [Integer] subscription_id Unique ID of the subscription
  def accept(addresses, active = [], raw: false, delay: 1, subscription_id: rand(99_999))
    raise 'Addresses can\'t be nil' unless addresses
    raise 'Addresses must respond to .to_a()' unless addresses.respond_to?(:to_a)
    raise 'Active can\'t be nil' unless active
    raise 'Active must respond to .append()' unless active.respond_to?(:append)
    raise 'Amount must be an Integer' unless delay.is_a?(Integer)
    raise 'Amount must be a positive Integer' unless delay.positive?
    raise 'Subscription ID must be an Integer' unless subscription_id.is_a?(Integer)
    raise 'Subscription ID must be a positive Integer' unless subscription_id.positive?
    EventMachine.run do
      u = url(http: false)
      @log.debug("Connecting to #{u.hostname}:#{u.port}...")
      ws = Faye::WebSocket::Client.new(u.to_s, [], proxy: @proxy ? { origin: @proxy } : {})
      log = @log
      contract = @contract
      attempt = []
      log_url = "ws#{@ssl ? 's' : ''}://#{u.hostname}:#{u.port}"
      ws.on(:open) do
        verbose do
          log.debug("Connected to #{log_url}")
        end
      end
      ws.on(:message) do |msg|
        verbose do
          data = to_json(msg)
          if data['id']
            before = active.to_a
            attempt.each do |a|
              active.append(a) unless before.include?(a)
            end
            log.debug(
              "Subscribed ##{subscription_id} to #{active.to_a.size} addresses at #{log_url}: " \
              "#{active.to_a.map { |a| a[0..6] }.join(', ')}"
            )
          elsif data['method'] == 'eth_subscription' && data.dig('params', 'result')
            event = data['params']['result']
            if raw
              log.debug("New event arrived from #{event['address']}")
            else
              event = {
                amount: event['data'].to_i(16),
                from: "0x#{event['topics'][1][26..].downcase}",
                to: "0x#{event['topics'][2][26..].downcase}",
                txn: event['transactionHash'].downcase
              }
              log.debug(
                "Payment of #{event[:amount]} tokens arrived" \
                "from #{event[:from]} to #{event[:to]} in #{event[:txn]}"
              )
            end
            yield event
          end
        end
      end
      ws.on(:close) do
        verbose do
          log.debug("Disconnected from #{log_url}")
        end
      end
      ws.on(:error) do |e|
        verbose do
          log.debug("Error at #{log_url}: #{e.message}")
        end
      end
      EventMachine.add_periodic_timer(delay) do
        next if active.to_a.sort == addresses.to_a.sort
        attempt = addresses.to_a
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
        log.debug(
          "Requested to subscribe ##{subscription_id} to #{addresses.to_a.size} addresses at #{log_url}: " \
          "#{addresses.to_a.map { |a| a[0..6] }.join(', ')}"
        )
      end
    end
  end

  private

  def to_json(msg)
    JSON.parse(msg.data)
  rescue StandardError
    {}
  end

  def verbose
    yield
  rescue StandardError => e
    @log.error(Backtrace.new(e).to_s)
    raise e
  end

  def url(http: true)
    URI.parse("#{http ? 'http' : 'ws'}#{@ssl ? 's' : ''}://#{@host}:#{@port}#{http ? @http_path : @ws_path}")
  end

  def jsonrpc
    JSONRPC.logger = Loog::NULL
    connection =
      if @proxy
        uri = URI.parse(@proxy)
        Faraday.new do |f|
          f.adapter(Faraday.default_adapter)
          f.proxy = {
            uri: "#{uri.scheme}://#{uri.hostname}:#{uri.port}",
            user: uri.user,
            password: uri.password
          }
        end
      end
    JSONRPC::Client.new(url, connection:)
  end

  def gas_estimate(from, data)
    jsonrpc.eth_estimateGas({ from:, to: @contract, data: }, 'latest').to_i(16)
  end

  def gas_best_price
    jsonrpc.eth_getBlockByNumber('latest', false)['baseFeePerGas'].to_i(16)
  end
end
