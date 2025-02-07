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

require 'donce'
require 'loog'
require 'random-port'
require 'minitest/autorun'
require_relative '../../lib/erc20'
require_relative '../../lib/erc20/wallet'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2025 Yegor Bugayenko
# License:: MIT
class TestWallet < Minitest::Test
  # At this address, in the mainnet, there are a few USDT tokens. I won't
  # move them anyway, that's why tests can use this address forever.
  STABLE_ADDRESS = '0xEB2fE8872A6f1eDb70a2632EA1f869AB131532f6'

  def test_checks_balance_on_mainnet
    b = mainnet.balance(STABLE_ADDRESS)
    refute_nil(b)
    assert_equal(27_258_889, b)
  end

  def test_checks_balance_of_absent_address
    a = '0xEB2fE8872A6f1eDb70a2632Effffffffffffffff'
    b = mainnet.balance(a)
    refute_nil(b)
    assert_equal(0, b)
  end

  def test_fails_with_invalid_infura_key
    w = ERC20::Wallet.new(
      rpc: 'https://mainnet.infura.io/v3/invalid-key-here',
      log: Loog::NULL
    )
    assert_raises(StandardError) { w.balance(STABLE_ADDRESS) }
  end

  def test_checks_balance_on_testnet
    skip('does not work')
    b = testnet.balance(STABLE_ADDRESS)
    refute_nil(b)
    assert_predicate(b, :positive?)
  end

  def test_checks_balance_on_hardhat
    RandomPort::Pool::SINGLETON.acquire do |port|
      qbash('npx --config=/app/hardhat.config.ts hardhat node') do |pid|
      # donce(
      #   home: File.join(__dir__, '../../hardhat'),
      #   ports: { port => 8545 },
      #   command: 'npx --config=/app/hardhat.config.ts hardhat node',
      #   log: Loog::VERBOSE,
      #   root: true
      # ) do |_|
        sleep 3
        w = ERC20::Wallet.new(rpc: "https://#{donce_host}:#{port}", log: Loog::VERBOSE)
        b = w.balance('0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266')
        assert_equal(11000, b)
      end
    end
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

  def env(var)
    key = ENV.fetch(var)
    skip("The #{var} environment variable is not set") if key.nil?
    key
  end

  def mainnet
    [
      "https://mainnet.infura.io/v3/#{env('INFURA_KEY')}",
      "https://go.getblock.io/#{env('GETBLOCK_KEY')}"
    ].map do |rpc|
      ERC20::Wallet.new(rpc:, log: Loog::NULL)
    end.sample
  end

  def testnet
    [
      "https://sepolia.infura.io/v3/#{env('INFURA_KEY')}",
      "https://go.getblock.io/#{env('GETBLOCK_SEPOILA_KEY')}"
    ].map do |rpc|
      ERC20::Wallet.new(rpc:, log: Loog::NULL)
    end.sample
  end
end
