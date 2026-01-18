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
end
