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
  def initialize(contract: USDT, rpc: '', chain: 1, log: $stdout)
    @contract = contract
    @rpc = rpc
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
    r[2..].to_i(16)
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
    jsonrpc.eth_sendRawTransaction("0x#{tx.hex}")
  end

  # Wait for incoming transactions and let the block know when they
  # arrive. It's a blocking call, it's better to run it in a separate
  # thread.
  #
  # @param [Array<String>] _keys Private keys
  def accept(_keys)
    # do it
  end

  private

  def jsonrpc
    JSONRPC.logger = @log
    JSONRPC::Client.new(@rpc)
  end

  def gas_estimate(from, data)
    jsonrpc.eth_estimateGas({ from:, to: @contract, data: }, 'latest').to_i(16)
  end

  def gas_best_price
    jsonrpc.eth_getBlockByNumber('latest', false)['baseFeePerGas'].to_i(16)
  end
end
