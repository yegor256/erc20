# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'backtrace'
require 'donce'
require 'eth'
require 'faraday'
require 'fileutils'
require 'json'
require 'os'
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
class TestWallet < ERC20::Test
  # One guy private hex.
  JEFF = '81a9b2114d53731ecc84b261ef6c0387dde34d5907fe7b441240cc21d61bf80a'

  # Another guy private hex.
  WALTER = '91f9111b1744d55361e632771a4e53839e9442a9fef45febc0a5c838c686a15b'

  def test_logs_to_stdout
    WebMock.disable_net_connect!
    stub_request(:post, 'https://example.org/').to_return(
      body: { jsonrpc: '2.0', id: 42, result: '0x1F1F1F' }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    w = ERC20::Wallet.new(
      host: 'example.org',
      http_path: '/',
      log: $stdout
    )
    w.balance(Eth::Key.new(priv: JEFF).address.to_s)
  end

  def test_checks_balance_on_testnet
    WebMock.enable_net_connect!
    b = testnet.balance(Eth::Key.new(priv: JEFF).address.to_s)
    refute_nil(b)
    assert_predicate(b, :zero?)
  end

  def test_checks_gas_estimate_on_hardhat
    WebMock.enable_net_connect!
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
    WebMock.enable_net_connect!
    on_hardhat do |wallet|
      b = wallet.balance(Eth::Key.new(priv: JEFF).address.to_s)
      assert_equal(123_000_100_000, b)
    end
  end

  def test_checks_eth_balance_on_hardhat
    WebMock.enable_net_connect!
    on_hardhat do |wallet|
      b = wallet.balance(Eth::Key.new(priv: WALTER).address.to_s)
      assert_equal(456_000_000_000, b)
    end
  end

  def test_checks_balance_on_hardhat_in_threads
    WebMock.enable_net_connect!
    on_hardhat do |wallet|
      Threads.new.assert do
        b = wallet.balance(Eth::Key.new(priv: JEFF).address.to_s)
        assert_equal(123_000_100_000, b)
      end
    end
  end

  def test_pays_on_hardhat
    WebMock.enable_net_connect!
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
    WebMock.enable_net_connect!
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
    WebMock.enable_net_connect!
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
    WebMock.enable_net_connect!
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
    WebMock.enable_net_connect!
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
          fake_loog.error(Backtrace.new(e))
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

  def test_accepts_payments_on_hardhat_after_disconnect
    skip('Works only on macOS') unless OS.mac?
    WebMock.enable_net_connect!
    walter = Eth::Key.new(priv: WALTER).address.to_s.downcase
    Dir.mktmpdir do |home|
      die = File.join(home, 'die.txt')
      on_hardhat(die:) do |wallet|
        active = []
        events = []
        daemon =
          Thread.new do
            wallet.accept([walter], active, subscription_id: 42) do |e|
              events.append(e)
            end
          rescue StandardError => e
            fake_loog.error(Backtrace.new(e))
          end
        wait_for { !active.empty? }
        wallet.pay(JEFF, walter, 4_567)
        wait_for { events.size == 1 }
        FileUtils.touch(die)
        on_hardhat(port: wallet.port) do
          wallet.pay(JEFF, walter, 3_456)
          wait_for { events.size > 1 }
          daemon.kill
          daemon.join(30)
          assert_equal(3, events.size)
        end
      end
    end
  end

  def test_accepts_many_payments_on_hardhat
    WebMock.enable_net_connect!
    walter = Eth::Key.new(priv: WALTER).address.to_s.downcase
    on_hardhat do |wallet|
      active = []
      events = Concurrent::Set.new
      total = 10
      daemon =
        Thread.new do
          wallet.accept([walter], active) do |e|
            events.add(e)
          end
        rescue StandardError => e
          fake_loog.error(Backtrace.new(e))
        end
      wait_for { !active.empty? }
      sum = 1_234
      Threads.new(total).assert do
        wallet.pay(JEFF, walter, sum)
      end
      wait_for { events.size == total }
      daemon.kill
      daemon.join(30)
      assert_equal(total, events.size)
    end
  end

  def test_accepts_payments_with_failures_on_hardhat
    WebMock.enable_net_connect!
    walter = Eth::Key.new(priv: WALTER).address.to_s.downcase
    on_hardhat do |wallet|
      active = []
      events = Concurrent::Set.new
      total = 10
      daemon =
        Thread.new do
          wallet.accept([walter], active) do |e|
            events.add(e)
            raise 'intentional'
          end
        end
      wait_for { !active.empty? }
      sum = 1_234
      Threads.new(total).assert do
        wallet.pay(JEFF, walter, sum)
      end
      wait_for { events.size == total }
      daemon.kill
      daemon.join(30)
      assert_equal(total, events.size)
    end
  end

  def test_accepts_payments_on_changing_addresses_on_hardhat
    WebMock.enable_net_connect!
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
          fake_loog.error(Backtrace.new(e))
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
    WebMock.enable_net_connect!
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
            fake_loog.error(Backtrace.new(e))
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

  def test_checks_balance_via_proxy
    WebMock.enable_net_connect!
    b = nil
    via_proxy do |proxy|
      on_hardhat do |w|
        wallet = through_proxy(w, proxy)
        b = wallet.balance(Eth::Key.new(priv: JEFF).address.to_s)
      end
    end
    assert_equal(123_000_100_000, b)
  end
end
