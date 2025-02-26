# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

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
require_relative '../test__helper'
require_relative '../../lib/erc20/wallet'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2025 Yegor Bugayenko
# License:: MIT
class TestWallet < Minitest::Test
  # At this address, in Etherium mainnet, there are $8 USDT and 0.0042 ETH. I won't
  # move them anyway, that's why tests can use this address forever.
  STABLE = '0x7232148927F8a580053792f44D4d59d40Fd00ABD'

  # One guy private hex.
  JEFF = '81a9b2114d53731ecc84b261ef6c0387dde34d5907fe7b441240cc21d61bf80a'

  # Another guy private hex.
  WALTER = '91f9111b1744d55361e632771a4e53839e9442a9fef45febc0a5c838c686a15b'

  def test_checks_balance_on_mainnet
    b = mainnet.balance(STABLE)
    refute_nil(b)
    assert_equal(8_000_000, b) # this is $8 USDT
  end

  def test_checks_eth_balance_on_mainnet
    b = mainnet.eth_balance(STABLE)
    refute_nil(b)
    assert_equal(4_200_000_000_000_000, b) # this is 0.0042 ETH
  end

  def test_checks_balance_of_absent_address
    a = '0xEB2fE8872A6f1eDb70a2632Effffffffffffffff'
    b = mainnet.balance(a)
    refute_nil(b)
    assert_equal(0, b)
  end

  def test_checks_gas_estimate_on_mainnet
    b = mainnet.gas_estimate(STABLE, Eth::Key.new(priv: JEFF).address.to_s, 44_000)
    refute_nil(b)
    assert_predicate(b, :positive?)
    assert_operator(b, :>, 1000)
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

  def test_checks_gas_estimate_on_hardhat
    sum = 100_000
    on_hardhat do |wallet|
      b1 = wallet.gas_estimate(
        Eth::Key.new(priv: JEFF).address.to_s,
        Eth::Key.new(priv: WALTER).address.to_s,
        sum
      )
      assert_operator(b1, :>, 21_000)
    end
  end

  def test_checks_balance_on_hardhat
    on_hardhat do |wallet|
      b = wallet.balance(Eth::Key.new(priv: JEFF).address.to_s)
      assert_equal(123_000_100_000, b)
    end
  end

  def test_checks_eth_balance_on_hardhat
    on_hardhat do |wallet|
      b = wallet.balance(Eth::Key.new(priv: WALTER).address.to_s)
      assert_equal(456_000_000_000, b)
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

  def test_eth_pays_on_hardhat
    on_hardhat do |wallet|
      to = Eth::Key.new(priv: WALTER).address.to_s
      before = wallet.eth_balance(to)
      sum = 42_000
      from = Eth::Key.new(priv: JEFF).address.to_s
      assert_operator(wallet.eth_balance(from), :>, sum * 2)
      txn = wallet.eth_pay(JEFF, to, sum)
      assert_equal(66, txn.length)
      assert_match(/^0x[a-f0-9]{64}$/, txn)
      assert_equal(before + sum, wallet.eth_balance(to))
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

  def test_pays_eth_on_hardhat_in_threads
    on_hardhat do |wallet|
      to = Eth::Key.new(priv: WALTER).address.to_s
      before = wallet.eth_balance(to)
      sum = 42_000
      mul = 10
      Threads.new(mul).assert do
        wallet.eth_pay(JEFF, to, sum)
      end
      assert_equal(before + (sum * mul), wallet.eth_balance(to))
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
        assert_equal(8_000_000, w.balance(STABLE))
      end
    end
  end

  def test_pays_on_mainnet
    skip('This is live, must be run manually')
    w = mainnet
    print 'Enter Etherium ERC20 private key (64 chars): '
    priv = gets.chomp
    to = '0xEB2fE8872A6f1eDb70a2632EA1f869AB131532f6'
    txn = w.pay(priv, to, 1_990_000)
    assert_equal(66, txn.length)
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
