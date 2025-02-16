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

require 'backtrace'
require 'donce'
require 'eth'
require 'faraday'
require 'loog'
require 'minitest/autorun'
require 'random-port'
require 'shellwords'
require 'threads'
require 'typhoeus'
require_relative '../../lib/erc20/fake_wallet'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2025 Yegor Bugayenko
# License:: MIT
class TestFakeWallet < Minitest::Test
  def test_checks_fake_balance
    b = ERC20::FakeWallet.new.balance('0xEB2fE8872A6f1eDb70a2632Effffffffffffffff')
    refute_nil(b)
  end

  def test_checks_fake_eth_balance
    b = ERC20::FakeWallet.new.eth_balance('0xEB2fE8872A6f1eDb70a2632Effffffffffffffff')
    refute_nil(b)
  end

  def test_returns_host
    assert_equal('example.com', ERC20::FakeWallet.new.host)
  end

  def test_pays_fake_money
    priv = '81a9b2114d53731ecc84b261ef6c0387dde34d5907fe7b441240cc21d61bf80a'
    to = '0xfadef8ba4a5d709a2bf55b7a8798c9b438c640c1'
    txn = ERC20::FakeWallet.new.pay(Eth::Key.new(priv:), to, 555)
    assert_equal(66, txn.length)
    assert_match(/^0x[a-f0-9]{64}$/, txn)
  end

  def test_accepts_payments_on_hardhat
    active = Primitivo.new([])
    addresses = Primitivo.new(['0xfadef8ba4a5d709a2bf55b7a8798c9b438c640c1'])
    event = nil
    daemon =
      Thread.new do
        ERC20::FakeWallet.new.accept(addresses, active, delay: 0.1) do |e|
          event = e
        end
      rescue StandardError => e
        loog.error(Backtrace.new(e))
      end
    wait_for { !active.to_a.empty? }
    wait_for { !event.nil? }
    daemon.kill
    daemon.join(30)
    refute_nil(event)
  end
end
