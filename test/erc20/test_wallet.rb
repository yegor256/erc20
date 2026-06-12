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
require_relative '../../lib/erc20/wallet'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2025 Yegor Bugayenko
# License:: MIT
class TestWallet < ERC20::Test
  JEFF = '81a9b2114d53731ecc84b261ef6c0387dde34d5907fe7b441240cc21d61bf80a'

  WALTER = '91f9111b1744d55361e632771a4e53839e9442a9fef45febc0a5c838c686a15b'

  def test_logs_to_stdout
    WebMock.disable_net_connect!
    stub_request(:post, 'https://example.org/').to_return(
      body: { jsonrpc: '2.0', id: 42, result: '0x1F1F1F' }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    ERC20::Wallet.new(
      host: 'example.org', http_path: '/',
      log: $stdout
    ).balance(Eth::Key.new(priv: JEFF).address.to_s)
  end

  def test_checks_balance_on_testnet
    WebMock.enable_net_connect!
    b = testnet.balance(Eth::Key.new(priv: JEFF).address.to_s)
    refute_nil(b)
    assert_predicate(b, :zero?)
  end

  CHALLENGE = '<!DOCTYPE html><html><head><title>Just a moment...</title></head></html>'

  GOOD_JSON = { jsonrpc: '2.0', id: 42, result: '0x1F1F1F' }.to_json

  def test_retries_on_transient_non_json_response
    WebMock.disable_net_connect!
    stub_request(:post, 'https://example.org/').to_return(
      { status: 200, body: CHALLENGE, headers: { 'Content-Type' => 'text/html' } },
      { status: 200, body: GOOD_JSON, headers: { 'Content-Type' => 'application/json' } }
    )
    w = ERC20::Wallet.new(host: 'example.org', http_path: '/', attempts: 3, log: Loog::NULL)
    w.define_singleton_method(:sleep) { |*| nil }
    assert_equal(0x1F1F1F, w.balance(Eth::Key.new(priv: JEFF).address.to_s))
  end

  def test_fails_after_exhausting_attempts
    WebMock.disable_net_connect!
    stub_request(:post, 'https://example.org/').to_return(
      status: 200, body: CHALLENGE, headers: { 'Content-Type' => 'text/html' }
    )
    w = ERC20::Wallet.new(host: 'example.org', http_path: '/', attempts: 3, log: Loog::NULL)
    w.define_singleton_method(:sleep) { |*| nil }
    assert_raises(StandardError) do
      w.balance(Eth::Key.new(priv: JEFF).address.to_s)
    end
  end

  def test_falls_back_to_secondary_endpoint
    WebMock.disable_net_connect!
    stub_request(:post, 'https://example.org/').to_return(
      status: 200, body: CHALLENGE, headers: { 'Content-Type' => 'text/html' }
    )
    stub_request(:post, 'https://backup.example.org/').to_return(
      status: 200, body: GOOD_JSON, headers: { 'Content-Type' => 'application/json' }
    )
    w = ERC20::Wallet.new(
      host: 'example.org', http_path: '/',
      fallbacks: ['https://backup.example.org/'], attempts: 2, log: Loog::NULL
    )
    w.define_singleton_method(:sleep) { |*| nil }
    assert_equal(0x1F1F1F, w.balance(Eth::Key.new(priv: JEFF).address.to_s))
  end

  def test_rejects_non_array_fallbacks
    WebMock.disable_net_connect!
    assert_raises(ArgumentError) do
      ERC20::Wallet.new(host: 'example.org', http_path: '/', fallbacks: 'https://x.org/', log: Loog::NULL)
    end
  end

  def test_rejects_negative_attempts
    WebMock.disable_net_connect!
    assert_raises(ArgumentError) do
      ERC20::Wallet.new(host: 'example.org', http_path: '/', attempts: 0, log: Loog::NULL)
    end
  end

  def test_rejects_gas_limit_below_minimum
    WebMock.disable_net_connect!
    w = ERC20::Wallet.new(host: 'example.org', http_path: '/', log: Loog::NULL)
    assert_raises(ArgumentError) do
      w.pay(JEFF, Eth::Key.new(priv: WALTER).address.to_s, 1000, limit: 20_999, price: 1000)
    end
  end

  def test_rejects_gas_limit_above_maximum
    WebMock.disable_net_connect!
    w = ERC20::Wallet.new(host: 'example.org', http_path: '/', log: Loog::NULL)
    assert_raises(ArgumentError) do
      w.pay(JEFF, Eth::Key.new(priv: WALTER).address.to_s, 1000, limit: 30_000_001, price: 1000)
    end
  end
end
