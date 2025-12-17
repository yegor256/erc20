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
class TestWalletLive < ERC20::Test
  # At this address, in Ethereum mainnet, there are $8 USDT and 0.0042 ETH. I won't
  # move them anyway, that's why tests can use this address forever.
  STABLE = '0x7232148927F8a580053792f44D4d59d40Fd00ABD'

  def test_checks_balance_on_mainnet
    WebMock.enable_net_connect!
    b = mainnet.balance(STABLE)
    refute_nil(b)
    assert_equal(8_000_000, b) # this is $8 USDT
  end

  def test_checks_eth_balance_on_mainnet
    WebMock.enable_net_connect!
    b = mainnet.eth_balance(STABLE)
    refute_nil(b)
    assert_equal(4_200_000_000_000_000, b) # this is 0.0042 ETH
  end

  def test_checks_balance_of_absent_address
    WebMock.enable_net_connect!
    a = '0xEB2fE8872A6f1eDb70a2632Effffffffffffffff'
    b = mainnet.balance(a)
    refute_nil(b)
    assert_equal(0, b)
  end

  def test_checks_gas_estimate_on_mainnet
    WebMock.enable_net_connect!
    b = mainnet.gas_estimate(STABLE, '0x7232148927F8a580053792f44D4d5FFFFFFFFFFF', 44_000)
    refute_nil(b)
    assert_predicate(b, :positive?)
    assert_operator(b, :>, 1000)
  end

  def test_fails_with_invalid_infura_key
    WebMock.enable_net_connect!
    skip('Apparently, even with invalid key, Infura returns balance')
    w = ERC20::Wallet.new(
      contract: ERC20::Wallet.USDT,
      host: 'mainnet.infura.io',
      http_path: '/v3/invalid-key-here',
      log: fake_loog
    )
    assert_raises(StandardError) { w.balance(STABLE) }
  end

  def test_checks_balance_on_polygon
    WebMock.enable_net_connect!
    w = ERC20::Wallet.new(
      contract: '0xc2132D05D31c914a87C6611C10748AEb04B58e8F',
      host: 'polygon-mainnet.infura.io',
      http_path: "/v3/#{env('INFURA_KEY')}",
      log: fake_loog
    )
    b = w.balance(STABLE)
    refute_nil(b)
    assert_predicate(b, :zero?)
  end

  def test_accepts_payments_on_mainnet
    WebMock.enable_net_connect!
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
        fake_loog.error(Backtrace.new(e))
      end
    wait_for { !active.empty? }
    daemon.kill
    daemon.join(30)
    refute(failed)
  end

  def test_pings_google_via_proxy
    WebMock.enable_net_connect!
    via_proxy do |proxy|
      assert_equal(204, Typhoeus::Request.get('https://www.google.com/generate_204', proxy:).code)
    end
  end

  def test_checks_balance_via_proxy_on_mainnet
    WebMock.enable_net_connect!
    via_proxy do |proxy|
      w = ERC20::Wallet.new(
        host: 'mainnet.infura.io',
        http_path: "/v3/#{env('INFURA_KEY')}",
        proxy:, log: fake_loog
      )
      assert_equal(8_000_000, w.balance(STABLE))
    end
  end

  def test_pays_on_mainnet
    WebMock.enable_net_connect!
    skip('This is live, must be run manually')
    w = mainnet
    print 'Enter Ethereum ERC20 private key (64 chars): '
    priv = gets.chomp
    to = '0xEB2fE8872A6f1eDb70a2632EA1f869AB131532f6'
    txn = w.pay(priv, to, 1_990_000)
    assert_equal(66, txn.length)
  end
end
