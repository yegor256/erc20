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
  # @param [String] host The host of the server
  # @param [Object] log The destination for logs
  def initialize(contract: ERC20::Wallet::USDT, host: '', log: $stdout)
    @contract = contract
    @host = host
    @log = log
  end

  # Send a single payment from a private address to a public one.
  #
  # @param [String] sender Private key, in hex
  # @param [String] receiver Public key, in hex
  # @param [Integer] amount The amount to send
  # @return [String] Transaction hash
  def pay(_sender, _receiver, _amount)
    # do it
    'abcdef'
  end

  # Wait for incoming transactions and let the block know when they
  # arrive. It's a blocking call, it's better to run it in a separate
  # thread.
  #
  # @param [Array<String>] keys Private keys
  def accept(_keys)
    # do it
  end
end
