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
require 'jsonrpc/client'
require 'loog'
require 'websocket-client-simple'
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

  # Constructor.
  # @param [String] contract Hex of the contract in Etherium
  # @param [String] rpc The URL of Etherium JSON-RPC provider
  # @param [Integer] chain The ID of the chain (1 for mainnet)
  # @param [Object] log The destination for logs
  def initialize(contract: USDT, rpc: nil, wss: nil, chain: 1, log: $stdout)
    @contract = contract
    @rpc = rpc
    @wss = wss
    @log = log
    @chain = chain
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
    WebSocket::Client::Simple.connect(@wss) do |ws|
      log = @log
      contract = @contract
      wss = @wss
      ws.on(:open) do
        log.debug("Connected to #{wss}")
        msg = {
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
        }
        ws.send(msg.to_json)
        connected.append(1)
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
          log.debug("New transaction from: #{event['address']}")
          unless raw
            event = {
              amount: event['data'].to_i(16),
              from: "0x#{event['topics'][1][26..].downcase}",
              to: "0x#{event['topics'][2][26..].downcase}"
            }
          end
          yield event
        end
      end
      ws.on(:close) do |_e|
        log.debug("Disconnected from #{wss}")
      end
      ws.on(:error) do |e|
        log.debug("Error at #{wss}: #{e}")
      end
    end
  end

  private

  def jsonrpc
    JSONRPC.logger = Loog::NULL
    JSONRPC::Client.new(@rpc)
  end

  def gas_estimate(from, data)
    jsonrpc.eth_estimateGas({ from:, to: @contract, data: }, 'latest').to_i(16)
  end

  def gas_best_price
    jsonrpc.eth_getBlockByNumber('latest', false)['baseFeePerGas'].to_i(16)
  end
end
