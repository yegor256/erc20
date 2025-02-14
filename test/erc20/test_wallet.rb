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
require_relative '../../lib/erc20/wallet'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2025 Yegor Bugayenko
# License:: MIT
class TestWallet < Minitest::Test
  # At this address, in Etherium mainnet, there are a ~$27 USDT. I won't
  # move them anyway, that's why tests can use this address forever.
  STABLE = '0xEB2fE8872A6f1eDb70a2632EA1f869AB131532f6'

  # One guy private hex.
  JEFF = '81a9b2114d53731ecc84b261ef6c0387dde34d5907fe7b441240cc21d61bf80a'

  # Another guy private hex.
  WALTER = '91f9111b1744d55361e632771a4e53839e9442a9fef45febc0a5c838c686a15b'

  def test_checks_balance_on_mainnet
    b = mainnet.balance(STABLE)
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
    skip('Apparently, even with invalid key, Infura returns balance')
    w = ERC20::Wallet.new(
      host: 'mainnet.infura.io',
      http_path: '/v3/invalid-key-here',
      log: loog
    )
    assert_raises(StandardError) { p w.balance(STABLE) }
  end

  def test_checks_balance_on_testnet
    b = testnet.balance(STABLE)
    refute_nil(b)
    assert_predicate(b, :zero?)
  end

  def test_checks_balance_on_polygon
    w = ERC20::Wallet.new(
      contract: '0xc2132D05D31c914a87C6611C10748AEb04B58e8F',
      host: 'polygon-mainnet.infura.io', http_path: "/v3/#{env('INFURA_KEY')}",
      log: loog
    )
    b = w.balance(STABLE)
    refute_nil(b)
    assert_predicate(b, :zero?)
  end

  def test_checks_balance_on_hardhat
    on_hardhat do |wallet|
      b = wallet.balance(Eth::Key.new(priv: JEFF).address.to_s)
      assert_equal(123_000_100_000, b)
    end
  end

  def test_checks_balance_on_hardhat_in_threads
    on_hardhat do |wallet|
      Threads.new.assert do
        b = wallet.balance(Eth::Key.new(priv: JEFF).address.to_s)
        assert_equal(123_000_100_000, b)
      end
    end
  end

  def test_pays_on_hardhat
    on_hardhat do |wallet|
      to = Eth::Key.new(priv: WALTER).address.to_s
      before = wallet.balance(to)
      sum = 42_000
      from = Eth::Key.new(priv: JEFF).address.to_s
      assert_operator(wallet.balance(from), :>, sum * 2)
      txn = wallet.pay(JEFF, to, sum)
      assert_equal(66, txn.length)
      assert_match(/^0x[a-f0-9]{64}$/, txn)
      assert_equal(before + sum, wallet.balance(to))
    end
  end

  def test_pays_on_hardhat_in_threads
    on_hardhat do |wallet|
      to = Eth::Key.new(priv: WALTER).address.to_s
      before = wallet.balance(to)
      sum = 42_000
      mul = 10
      Threads.new(mul).assert do
        wallet.pay(JEFF, to, sum)
      end
      assert_equal(before + (sum * mul), wallet.balance(to))
    end
  end

  def test_accepts_payments_on_hardhat
    walter = Eth::Key.new(priv: WALTER).address.to_s.downcase
    jeff = Eth::Key.new(priv: JEFF).address.to_s.downcase
    on_hardhat do |wallet|
      active = []
      event = nil
      daemon =
        Thread.new do
          wallet.accept([walter, jeff], active) do |e|
            event = e
          end
        rescue StandardError => e
          loog.error(Backtrace.new(e))
        end
      wait_for { !active.empty? }
      sum = 77_000
      wallet.pay(JEFF, walter, sum)
      wait_for { !event.nil? }
      daemon.kill
      daemon.join(30)
      assert_equal(sum, event[:amount])
      assert_equal(jeff, event[:from])
      assert_equal(walter, event[:to])
      assert_equal(66, event[:txn].length)
    end
  end

  def test_accepts_payments_on_changing_addresses_on_hardhat
    walter = Eth::Key.new(priv: WALTER).address.to_s.downcase
    jeff = Eth::Key.new(priv: JEFF).address.to_s.downcase
    addresses = Primitivo.new([walter])
    on_hardhat do |wallet|
      active = Primitivo.new([])
      event = nil
      daemon =
        Thread.new do
          wallet.accept(addresses, active) do |e|
            event = e
          end
        rescue StandardError => e
          loog.error(Backtrace.new(e))
        end
      wait_for { active.to_a.include?(walter) }
      sum1 = 453_000
      wallet.pay(JEFF, walter, sum1)
      wait_for { !event.nil? }
      assert_equal(sum1, event[:amount])
      sum2 = 22_000
      event = nil
      addresses.append(jeff)
      wait_for { active.to_a.include?(jeff) }
      wallet.pay(WALTER, jeff, sum2)
      wait_for { !event.nil? }
      assert_equal(sum2, event[:amount])
      daemon.kill
      daemon.join(30)
    end
  end

  def test_accepts_payments_on_hardhat_via_proxy
    via_proxy do |proxy|
      walter = Eth::Key.new(priv: WALTER).address.to_s.downcase
      jeff = Eth::Key.new(priv: JEFF).address.to_s.downcase
      on_hardhat do |w|
        wallet = through_proxy(w, proxy)
        active = []
        event = nil
        daemon =
          Thread.new do
            wallet.accept([walter, jeff], active) do |e|
              event = e
            end
          rescue StandardError => e
            loog.error(Backtrace.new(e))
          end
        wait_for { !active.empty? }
        sum = 55_000
        wallet.pay(JEFF, walter, sum)
        wait_for { !event.nil? }
        daemon.kill
        daemon.join(30)
        assert_equal(sum, event[:amount])
      end
    end
  end

  def test_accepts_payments_on_mainnet
    active = []
    failed = false
    net = mainnet
    daemon =
      Thread.new do
        net.accept([STABLE], active) do |_|
          # ignore it
        end
      rescue StandardError => e
        failed = true
        loog.error(Backtrace.new(e))
      end
    wait_for { !active.empty? }
    daemon.kill
    daemon.join(30)
    refute(failed)
  end

  def test_checks_balance_via_proxy
    via_proxy do |proxy|
      on_hardhat do |w|
        wallet = through_proxy(w, proxy)
        b = wallet.balance(Eth::Key.new(priv: JEFF).address.to_s)
        assert_equal(123_000_100_000, b)
      end
    end
  end

  def test_checks_balance_via_proxy_on_mainnet
    via_proxy do |proxy|
      on_hardhat do
        w = ERC20::Wallet.new(
          host: 'mainnet.infura.io', http_path: "/v3/#{env('INFURA_KEY')}",
          proxy:, log: loog
        )
        assert_equal(27_258_889, w.balance(STABLE))
      end
    end
  end

  private

  def env(var)
    key = ENV.fetch(var, nil)
    skip("The #{var} environment variable is not set") if key.nil?
    key
  end

  def mainnet
    [
      {
        host: 'mainnet.infura.io',
        http_path: "/v3/#{env('INFURA_KEY')}",
        ws_path: "/ws/v3/#{env('INFURA_KEY')}"
      },
      {
        host: 'go.getblock.io',
        http_path: "/#{env('GETBLOCK_KEY')}",
        ws_path: "/#{env('GETBLOCK_WS_KEY')}"
      }
    ].map do |server|
      ERC20::Wallet.new(host: server[:host], http_path: server[:http_path], ws_path: server[:ws_path], log: loog)
    end.sample
  end

  def testnet
    [
      {
        host: 'sepolia.infura.io',
        http_path: "/v3/#{env('INFURA_KEY')}",
        ws_path: "/ws/v3/#{env('INFURA_KEY')}"
      },
      {
        host: 'go.getblock.io',
        http_path: "/#{env('GETBLOCK_SEPOILA_KEY')}",
        ws_path: "/#{env('GETBLOCK_SEPOILA_KEY')}"
      }
    ].map do |server|
      ERC20::Wallet.new(host: server[:host], http_path: server[:http_path], ws_path: server[:ws_path], log: loog)
    end.sample
  end

  def through_proxy(wallet, proxy)
    ERC20::Wallet.new(
      contract: wallet.contract, chain: wallet.chain,
      host: donce_host, port: wallet.port, http_path: wallet.http_path, ws_path: wallet.ws_path,
      ssl: wallet.ssl, proxy:, log: loog
    )
  end

  def via_proxy
    RandomPort::Pool::SINGLETON.acquire do |port|
      donce(
        image: 'yegor256/squid-proxy:latest',
        ports: { port => 3128 },
        env: { 'USERNAME' => 'jeffrey', 'PASSWORD' => 'swordfish' },
        root: true, log: loog
      ) do
        yield "http://jeffrey:swordfish@localhost:#{port}"
      end
    end
  end

  def on_hardhat
    RandomPort::Pool::SINGLETON.acquire do |port|
      donce(
        home: File.join(__dir__, '../../hardhat'),
        ports: { port => 8545 },
        command: 'npx hardhat node',
        log: loog
      ) do
        wait_for_port(port)
        cmd = [
          '(cat hardhat.config.js)',
          '(ls -al)',
          '(echo y | npx hardhat ignition deploy ./ignition/modules/Foo.ts --network foo --deployment-id foo)',
          '(npx hardhat ignition status foo | tail -1 | cut -d" " -f3)'
        ].join(' && ')
        contract = donce(
          home: File.join(__dir__, '../../hardhat'),
          command: "/bin/bash -c #{Shellwords.escape(cmd)}",
          build_args: { 'HOST' => donce_host, 'PORT' => port },
          log: loog,
          root: true
        ).split("\n").last
        wallet = ERC20::Wallet.new(
          contract:, chain: 4242,
          host: 'localhost', port:, http_path: '/', ws_path: '/', ssl: false,
          log: loog
        )
        yield wallet
      end
    end
  end
end
