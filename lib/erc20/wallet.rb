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
require 'faye/websocket'
require 'json'
require 'jsonrpc/client'
require 'loog'
require 'uri'
require_relative '../erc20'

# A wallet.
#
# It is NOT thread-safe!
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2025 Yegor Bugayenko
# License:: MIT
class ERC20::Wallet
  # Address of USDT contract.
  USDT = '0xdac17f958d2ee523a2206206994597c13d831ec7'

  # These properties are read-only:
  attr_reader :host, :port, :ssl, :chain, :contract, :path

  # Constructor.
  # @param [String] contract Hex of the contract in Etherium
  # @param [Integer] chain The ID of the chain (1 for mainnet)
  # @param [String] host The host to connect to
  # @param [Integer] port TCP port to use
  # @param [String] path The path in the connection URL
  # @param [Boolean] ssl Should we use SSL (for https and wss)
  # @param [String] proxy The URL of the proxy to use
  # @param [Object] log The destination for logs
  def initialize(contract: USDT, chain: 1, log: $stdout,
                 host: nil, port: 443, path: '/', ssl: true,
                 proxy: nil)
    @contract = contract
    @host = host
    @port = port
    @ssl = ssl
    @path = path
    @log = log
    @chain = chain
    @proxy = proxy
  end

  # Get balance of a public address.
  #
  # @param [String] hex Public key, in hex, starting from '0x'
  # @return [Integer] Balance, in
  def balance(hex)
    func = '70a08231' # balanceOf
    padded = "000000000000000000000000#{hex[2..].downcase}"
    data = "0x#{func}#{padded}"
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
  # @param [Integer] gas_limit How much gas you are ready to spend
  # @param [Integer] gas_price How much gas you pay per computation unit
  # @return [String] Transaction hash
  def pay(priv, address, amount, gas_limit: nil, gas_price: nil)
    func = 'a9059cbb' # transfer(address,uint256)
    to_clean = address.downcase.sub(/^0x/, '')
    to_padded = ('0' * (64 - to_clean.size)) + to_clean
    amt_hex = amount.to_s(16)
    amt_padded = ('0' * (64 - amt_hex.size)) + amt_hex
    data = "0x#{func}#{to_padded}#{amt_padded}"
    key = Eth::Key.new(priv: priv)
    from = key.address
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
    @log.debug("Sent #{amount} from #{from} to #{address}: #{hex}")
    hex
  end

  # Wait for incoming transactions and let the block know when they
  # arrive. It's a blocking call, it's better to run it in a separate
  # thread.
  #
  # @param [Array<String>] addresses Addresses to monitor
  # @param [Array] ready When connected, TRUE will be added to this array
  # @param [Boolean] raw TRUE if you need to get JSON events as they arrive from Websockets
  def accept(addresses, connected: [], raw: false)
    u = url('ws')
    @log.debug("Connecting to #{u}...")
    ws = Faye::WebSocket::Client.new(u)
    puts '111111111111111111111111111111111111111111111111111111111111111'
    log = @log
    contract = @contract
    ws.on(:open) do |event|
      puts '22222222222222222'
      log.debug("Connected to #{@host}")
      ws.send(
        {
          jsonrpc: '2.0',
          id: 1,
          method: 'eth_subscribe',
          params: [
            'logs',
            {
              address: contract,
              topics: [
                '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef',
                nil,
                addresses.map { |a| "0x000000000000000000000000#{a[2..]}" }
              ]
            }
          ]
        }.to_json
      )
      connected.append(1)
      log.debug("Subscribed to #{addresses.count} addresses")
    end
    ws.on(:message) do |msg|
      data =
        begin
          JSON.parse(msg.data)
        rescue StandardError
          {}
        end
      if data['method'] == 'eth_subscription' && data.dig('params', 'result')
        event = data['params']['result']
        unless raw
          event = {
            amount: event['data'].to_i(16),
            from: "0x#{event['topics'][1][26..].downcase}",
            to: "0x#{event['topics'][2][26..].downcase}"
          }
        end
        log.debug("New event arrived from #{event['address']}")
        yield event
      end
    end
    ws.on(:close) do |_e|
      log.debug("Disconnected from #{@host}")
    end
    ws.on(:error) do |e|
      log.debug("Error at #{@host}: #{e}")
    end
    puts '3333333333'
    sleep 10
  end

  private

  def url(prefix = 'http')
    "#{prefix}#{@ssl ? 's' : ''}://#{@host}:#{@port}#{@path}"
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
