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
require_relative '../../lib/erc20/fake_wallet'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2025 Yegor Bugayenko
# License:: MIT
class TestFakeWallet < Minitest::Test
  def test_checks_gas_estimate
    b = ERC20::FakeWallet.new.gas_estimate(
      '0xEB2fE8872A6f1eDb70a2632Effffffffffffffff',
      '0xfadef8ba4a5d709a2bf55b7a8798c9b438c640c1',
      44_000
    )
    refute_nil(b)
  end

  def test_checks_gas_price
    gwei = ERC20::FakeWallet.new.gas_price
    refute_nil(gwei)
  end

  def test_checks_fake_balance
    w = ERC20::FakeWallet.new
    a = '0xEB2fE8872A6f1eDb70a2632Effffffffffffffff'
    b = w.balance(a)
    refute_nil(b)
    assert_equal(42_000_000, b)
    assert_includes(w.history, { method: :balance, result: b, address: a })
  end

  def test_checks_preset_fake_balance
    w = ERC20::FakeWallet.new
    a = '0xEB2fE8872A6f1eDb70a2632Effffffffeefbbfaa'
    b = 55_555
    w.set_balance(a, b)
    assert_equal(b, w.balance(a))
  end

  def test_checks_fake_eth_balance
    a = '0xEB2fE8872A6f1eDb70a2632Ebbffffff66fff77f'
    w = ERC20::FakeWallet.new
    b = w.eth_balance(a)
    refute_nil(b)
    assert_equal(77_000_000_000_000_000, b)
    assert_includes(w.history, { method: :eth_balance, result: b, address: a })
  end

  def test_checks_preset_fake_eth_balance
    a = '0xEB2fE8872A6f1eDb70a2632Eff88fff99fff33ff'
    w = ERC20::FakeWallet.new
    b = 33_333
    w.set_eth_balance(a, b)
    assert_equal(b, w.eth_balance(a))
  end

  def test_returns_host
    assert_equal('example.com', ERC20::FakeWallet.new.host)
  end

  def test_pays_fake_money
    priv = '81a9b2114d53731ecc84b261ef6c0387dde34d5907fe7b441240cc21d61bf80a'
    address = '0xfadef8ba4a5d709a2bf55b7a8798c9b438c640c1'
    w = ERC20::FakeWallet.new
    amount = 555_000
    txn = w.pay(priv, address, amount)
    assert_equal(66, txn.length)
    assert_match(/^0x[a-f0-9]{64}$/, txn)
    assert_equal(ERC20::FakeWallet::TXN_HASH, txn)
    assert_includes(w.history, { method: :pay, result: txn, priv:, address:, amount:, gas_limit: nil, gas_price: nil })
  end

  def test_pays_fake_eths
    priv = '81a9b2114d53731ecc84b261ef6c0387dde34d5907fe7b441240cc21d61bf80a'
    to = '0xfadef8ba4a5d709a2bf55b7a8798c9b438c640c1'
    txn = ERC20::FakeWallet.new.eth_pay(Eth::Key.new(priv:), to, 555)
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
