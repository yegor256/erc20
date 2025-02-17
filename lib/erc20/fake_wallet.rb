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

require_relative 'erc20'
require_relative 'wallet'

# A fake wallet that behaves like a +ERC20::Wallet+.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2025 Yegor Bugayenko
# License:: MIT
class ERC20::FakeWallet
  # Fakes:
  attr_reader :host, :port, :ssl, :chain, :contract, :ws_path, :http_path

  # Full history of all method calls:
  attr_reader :history

  # Ctor.
  def initialize
    @host = 'example.com'
    @port = 443
    @ssl = true
    @chain = 1
    @contract = ERC20::Wallet::USDT
    @ws_path = '/'
    @http_path = '/'
    @history = []
  end

  # Get ERC20 balance of a public address.
  #
  # @param [String] address Public key, in hex, starting from '0x'
  # @return [Integer] Balance, in tokens
  def balance(address)
    b = 42_000_000
    @history << { method: :balance, address:, result: b }
    b
  end

  # Get ETH balance of a public address.
  #
  # @param [String] address Public key, in hex, starting from '0x'
  # @return [Integer] Balance, in tokens
  def eth_balance(address)
    b = 77_000_000_000_000_000
    @history << { method: :eth_balance, address:, result: b }
    b
  end

  # How much ETH gas is required in order to send this ERC20 transaction.
  #
  # @param [String] from The departing address, in hex
  # @param [String] to Arriving address, in hex
  # @return [Integer] How many ETH required
  def gas_required(from, to = from)
    g = 66_000
    @history << { method: :gas_required, from:, to:, result: g }
    g
  end

  # How much ETH gas is required in order to send this ETH transaction.
  #
  # @param [String] from The departing address, in hex
  # @param [String] to Arriving address, in hex (may be skipped)
  # @return [Integer] How many ETH required
  def eth_gas_required(from, to = from)
    g = 55_000
    @history << { method: :eth_gas_required, from:, to:, result: g }
    g
  end

  # Send a single ERC20 payment from a private address to a public one.
  #
  # @param [String] _priv Private key, in hex
  # @param [String] _address Public key, in hex
  # @param [Integer] _amount The amount of ERC20 tokens to send
  # @return [String] Transaction hash
  def pay(priv, address, amount, gas_limit: nil, gas_price: nil)
    hex = '0x172de9cda30537eae68ab4a96163ebbb8f8a85293b8737dd2e5deb4714b14623'
    @history << { method: :pay, priv:, address:, amount:, gas_limit:, gas_price:, result: hex }
    hex
  end

  # Send a single ETH payment from a private address to a public one.
  #
  # @param [String] priv Private key, in hex
  # @param [String] address Public key, in hex
  # @param [Integer] amount The amount of ETHs to send
  # @return [String] Transaction hash
  def eth_pay(priv, address, amount, gas_limit: nil, gas_price: nil)
    hex = '0x172de9cda30537eae68ab4a96163ebbb8f8a85293b8737dd2e5deb4714b14623'
    @history << { method: :eth_pay, priv:, address:, amount:, gas_limit:, gas_price:, result: hex }
    hex
  end

  # Wait and accept.
  #
  # @param [Array<String>] addresses Addresses to monitor
  # @param [Array] active List of addresses that we are actually listening to
  # @param [Boolean] raw TRUE if you need to get JSON events as they arrive from Websockets
  # @param [Integer] delay How many seconds to wait between +eth_subscribe+ calls
  def accept(addresses, active = [], raw: false, delay: 1)
    @history << { method: :accept, addresses:, active:, raw:, delay: }
    addresses.to_a.each { |a| active.append(a) }
    loop do
      sleep(delay)
      a = addresses.to_a.sample
      next if a.nil?
      event =
        if raw
          {}
        else
          {
            amount: 424_242,
            from: '0xd5ff1bfcde7a03da61ad229d962c74f1ea2f16a5',
            to: a,
            txn: '0x172de9cda30537eae68ab4a96163ebbb8f8a85293b8737dd2e5deb4714b14623'
          }
        end
      yield event
    end
  end
end
