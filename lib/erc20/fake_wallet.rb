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

  # Ctor.
  def initialize
    @host = 'example.com'
    @port = 443
    @ssl = true
    @chain = 1
    @contract = ERC20::Wallet::USDT
    @ws_path = '/'
    @http_path = '/'
  end

  # Get balance of a public address.
  #
  # @param [String] _hex Public key, in hex, starting from '0x'
  # @return [Integer] Balance, in tokens
  def balance(_hex)
    42_000_000
  end

  # Send a single payment from a private address to a public one.
  #
  # @param [String] _priv Private key, in hex
  # @param [String] _address Public key, in hex
  # @param [Integer] _amount The amount of ERC20 tokens to send
  # @return [String] Transaction hash
  def pay(_priv, _address, _amount, *)
    '0x172de9cda30537eae68ab4a96163ebbb8f8a85293b8737dd2e5deb4714b14623'
  end

  # Wait and accept.
  #
  # @param [Array<String>] addresses Addresses to monitor
  # @param [Array] active List of addresses that we are actually listening to
  # @param [Boolean] raw TRUE if you need to get JSON events as they arrive from Websockets
  # @param [Integer] delay How many seconds to wait between +eth_subscribe+ calls
  def accept(addresses, active = [], raw: false, delay: 1)
    addresses.to_a.each { |a| active.append(a) }
    loop do
      event =
        if raw
          {}
        else
          {
            amount: 424_242,
            from: '0xd5ff1bfcde7a03da61ad229d962c74f1ea2f16a5',
            to: addresses.sample,
            txn: '0x172de9cda30537eae68ab4a96163ebbb8f8a85293b8737dd2e5deb4714b14623'
          }
        end
      yield event
      sleep(delay)
    end
  end
end
