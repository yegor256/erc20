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

require 'minitest/autorun'
require 'loog'
require_relative '../../lib/erc20'
require_relative '../../lib/erc20/wallet'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2025 Yegor Bugayenko
# License:: MIT
class TestWallet < Minitest::Test
  def test_checks_balance_on_mainnet
    a = '0xEB2fE8872A6f1eDb70a2632EA1f869AB131532f6'
    b = mainnet.balance(a)
    refute_nil(b)
    assert_equal(27_258_889, b)
  end

  def test_checks_balance_on_sepolia
    skip('does not work yet')
    a = '0xf28A36f671CCb6bE6BF55E0e1D3C107263B1DFA1'
    b = sepolia.balance(a)
    refute_nil(b)
    assert_predicate(b, :positive?)
  end

  def test_sends_payment
    skip('does not work yet')
    w = ERC20::Wallet.new(log: Loog::VERBOSE)
    sender = Eth::Key.new
    receiver = Eth::Key.new
    txn = w.pay(sender.private_hex, receiver.public_hex, 100)
    refute_nil(txn)
  end

  def test_accepts_payments_to_my_addresses
    skip('does not work yet')
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

  private

  def infura_key
    var = 'INFURA_KEY'
    key = ENV.fetch(var)
    skip("The #{var} environment variable is not set") if key.nil?
    key
  end

  def mainnet
    ERC20::Wallet.new(
      contract: ERC20::Wallet::USDT,
      rpc: "https://mainnet.infura.io/v3/#{infura_key}",
      log: Loog::VERBOSE
    )
  end

  def sepolia
    ERC20::Wallet.new(
      contract: ERC20::Wallet::USDT,
      rpc: "https://sepolia.infura.io/v3/#{infura_key}",
      log: Loog::VERBOSE
    )
  end
end
