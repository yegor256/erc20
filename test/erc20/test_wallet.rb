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
require 'minitest/autorun'
require 'loog'
require_relative '../../lib/erc20'
require_relative '../../lib/erc20/wallet'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2025 Yegor Bugayenko
# License:: MIT
class TestWallet < Minitest::Test
  def test_send_payment
    w = ERC20::Wallet.new(log: Loog::VERBOSE)
    sender = Eth::Key.new
    receiver = Eth::Key.new
    txn = w.pay(sender.private_hex, receiver.public_hex, 100)
    refute_nil(txn)
  end

  def test_accept_payments_to_my_addresses
    receiver = Eth::Key.new
    w = ERC20::Wallet.new(log: Loog::VERBOSE)
    txn = nil
    daemon =
      Thread.new do
        w.accept([receiver.private_hex]) do |t|
          txn = t
        end
      end
    sender = Eth::Key.new
    w.pay(sender.private_hex, receiver.public_hex, 100)
    daemon.join(30)
    # refute_nil(txn)
  end
end
