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
require 'timeout'
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
      body: { jsonrpc: '2.0', id: 42, result: format('0x%064x', 0x1F1F1F) }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    ERC20::Wallet.new(
      host: 'example.org', http_path: '/',
      log: $stdout
    ).balance(Eth::Key.new(priv: JEFF).address.to_s)
  end

  def test_checks_balance_on_testnet
    WebMock.enable_net_connect!
    live do
      b = testnet.balance(Eth::Key.new(priv: JEFF).address.to_s)
      refute_nil(b)
      assert_predicate(b, :zero?)
    end
  end

  CHALLENGE = '<!DOCTYPE html><html><head><title>Just a moment...</title></head></html>'

  GOOD_JSON = { jsonrpc: '2.0', id: 42, result: format('0x%064x', 0x1F1F1F) }.to_json

  def test_rejects_empty_result_of_balance
    WebMock.disable_net_connect!
    stub_request(:post, 'https://example.org/').to_return(
      body: { jsonrpc: '2.0', id: 42, result: '0x' }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    w = ERC20::Wallet.new(host: 'example.org', http_path: '/', log: Loog::NULL)
    assert_raises(StandardError) do
      w.balance(Eth::Key.new(priv: JEFF).address.to_s)
    end
  end

  def test_rejects_empty_result_of_eth_balance
    WebMock.disable_net_connect!
    stub_request(:post, 'https://example.org/').to_return(
      body: { jsonrpc: '2.0', id: 42, result: '0x' }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    w = ERC20::Wallet.new(host: 'example.org', http_path: '/', log: Loog::NULL)
    assert_raises(StandardError) do
      w.eth_balance(Eth::Key.new(priv: JEFF).address.to_s)
    end
  end

  def test_rejects_truncated_result_of_balance
    WebMock.disable_net_connect!
    stub_request(:post, 'https://example.org/').to_return(
      body: { jsonrpc: '2.0', id: 42, result: '0x1F1F1F' }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    w = ERC20::Wallet.new(host: 'example.org', http_path: '/', log: Loog::NULL)
    assert_raises(StandardError) do
      w.balance(Eth::Key.new(priv: JEFF).address.to_s)
    end
  end

  def test_retries_on_transient_non_json_response
    WebMock.disable_net_connect!
    stub_request(:post, 'https://example.org/').to_return(
      { status: 200, body: CHALLENGE, headers: { 'Content-Type' => 'text/html' } },
      { status: 200, body: GOOD_JSON, headers: { 'Content-Type' => 'application/json' } }
    )
    w = ERC20::Wallet.new(host: 'example.org', http_path: '/', attempts: 3, log: Loog::NULL)
    w.define_singleton_method(:sleep) { |*| 0 }
    assert_equal(0x1F1F1F, w.balance(Eth::Key.new(priv: JEFF).address.to_s))
  end

  def test_fails_after_exhausting_attempts
    WebMock.disable_net_connect!
    stub_request(:post, 'https://example.org/').to_return(
      status: 200, body: CHALLENGE, headers: { 'Content-Type' => 'text/html' }
    )
    w = ERC20::Wallet.new(host: 'example.org', http_path: '/', attempts: 3, log: Loog::NULL)
    w.define_singleton_method(:sleep) { |*| 0 }
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
    w.define_singleton_method(:sleep) { |*| 0 }
    assert_equal(0x1F1F1F, w.balance(Eth::Key.new(priv: JEFF).address.to_s))
  end

  def test_falls_back_with_a_single_attempt
    WebMock.disable_net_connect!
    stub_request(:post, 'https://example.org/').to_return(
      status: 200, body: CHALLENGE, headers: { 'Content-Type' => 'text/html' }
    )
    stub_request(:post, 'https://backup.example.org/').to_return(
      status: 200, body: GOOD_JSON, headers: { 'Content-Type' => 'application/json' }
    )
    w = ERC20::Wallet.new(
      host: 'example.org', http_path: '/',
      fallbacks: ['https://backup.example.org/'], log: Loog::NULL
    )
    w.define_singleton_method(:sleep) { |*| 0 }
    assert_equal(0x1F1F1F, w.balance(Eth::Key.new(priv: JEFF).address.to_s))
  end

  def test_reaches_the_last_fallback
    WebMock.disable_net_connect!
    stub_request(:post, 'https://example.org/').to_return(
      status: 200, body: CHALLENGE, headers: { 'Content-Type' => 'text/html' }
    )
    stub_request(:post, 'https://first.example.org/').to_return(
      status: 200, body: CHALLENGE, headers: { 'Content-Type' => 'text/html' }
    )
    stub_request(:post, 'https://second.example.org/').to_return(
      status: 200, body: GOOD_JSON, headers: { 'Content-Type' => 'application/json' }
    )
    w = ERC20::Wallet.new(
      host: 'example.org', http_path: '/',
      fallbacks: ['https://first.example.org/', 'https://second.example.org/'], log: Loog::NULL
    )
    w.define_singleton_method(:sleep) { |*| 0 }
    assert_equal(0x1F1F1F, w.balance(Eth::Key.new(priv: JEFF).address.to_s))
  end

  def test_spends_all_attempts_on_every_endpoint
    WebMock.disable_net_connect!
    seen = []
    ['https://example.org/', 'https://backup.example.org/'].each do |endpoint|
      stub_request(:post, endpoint).to_return do |_|
        seen.append(endpoint)
        { status: 200, body: CHALLENGE, headers: { 'Content-Type' => 'text/html' } }
      end
    end
    w = ERC20::Wallet.new(
      host: 'example.org', http_path: '/',
      fallbacks: ['https://backup.example.org/'], attempts: 3, log: Loog::NULL
    )
    w.define_singleton_method(:sleep) { |*| 0 }
    begin
      w.balance(Eth::Key.new(priv: JEFF).address.to_s)
    rescue StandardError => e
      Loog::NULL.debug(e.message)
    end
    assert_equal(6, seen.size)
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

  def test_broadcasts_identical_transaction_on_retry
    WebMock.disable_net_connect!
    sent = []
    stub_request(:post, 'https://example.org/').to_return do |request|
      call = JSON.parse(request.body)
      if call['method'] == 'eth_sendRawTransaction'
        sent.append(call['params'].first)
        next { status: 200, body: CHALLENGE, headers: { 'Content-Type' => 'text/html' } } if sent.size == 1
        next {
          status: 200,
          body: { jsonrpc: '2.0', id: call['id'], result: "0x#{'f' * 64}" }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        }
      end
      {
        status: 200,
        body: { jsonrpc: '2.0', id: call['id'], result: "0x#{sent.size}" }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      }
    end
    w = ERC20::Wallet.new(host: 'example.org', http_path: '/', attempts: 3, log: Loog::NULL)
    w.define_singleton_method(:sleep) { |*| 0 }
    w.pay(JEFF, Eth::Key.new(priv: WALTER).address.to_s, 1000, limit: 60_000, price: 1000)
    assert_equal(1, sent.uniq.size)
  end

  def to_log(amount, removed: false, block: '0x10', index: '0x3')
    {
      address: ERC20::Wallet::USDT,
      blockNumber: block,
      data: format('0x%064x', amount),
      logIndex: index,
      removed:,
      topics: [
        ERC20::Wallet::TRANSFER,
        "0x000000000000000000000000#{Eth::Key.new(priv: JEFF).address.to_s.downcase[2..]}",
        "0x000000000000000000000000#{Eth::Key.new(priv: WALTER).address.to_s.downcase[2..]}"
      ],
      transactionHash: "0x#{'e' * 64}"
    }
  end

  def transfer(amount, removed)
    {
      jsonrpc: '2.0',
      method: 'eth_subscription',
      params: {
        subscription: '0x42',
        result: to_log(amount, removed:)
      }
    }
  end

  def test_ignores_payment_removed_by_reorg
    WebMock.enable_net_connect!
    walter = Eth::Key.new(priv: WALTER).address.to_s.downcase
    events = []
    on_websockets([[{ jsonrpc: '2.0', id: 42, result: '0x42' }, transfer(111, true), transfer(222, false)]]) do |wallet|
      daemon =
        Thread.new do
          wallet.accept([walter], [], subscription_id: 42) do |e|
            events.append(e)
          end
        end
      wait_for { !events.empty? }
      daemon.kill
      daemon.join(30)
    end
    assert_equal(222, events.first[:amount])
  end

  def confirmations
    [
      [{ jsonrpc: '2.0', id: 42, result: '0xaaa' }],
      [{ jsonrpc: '2.0', id: 43, result: true }],
      [{ jsonrpc: '2.0', id: 42, result: '0xbbb' }]
    ]
  end

  def test_unsubscribes_from_the_previous_subscription
    WebMock.enable_net_connect!
    addresses = [Eth::Key.new(priv: JEFF).address.to_s.downcase]
    sent = []
    on_websockets(confirmations) do |wallet, received|
      active = []
      daemon =
        Thread.new do
          wallet.accept(addresses, active, subscription_id: 42) { |event| event }
        end
      wait_for(10) { !active.empty? }
      addresses.append(Eth::Key.new(priv: WALTER).address.to_s.downcase)
      wait_for(10) do
        sent = File.readlines(received).map { |line| JSON.parse(line) }
        sent.any? { |m| m['method'] == 'eth_unsubscribe' }
      end
      daemon.kill
      daemon.join(30)
    end
    assert_equal(['0xaaa'], sent.find { |m| m['method'] == 'eth_unsubscribe' }['params'])
  end

  def test_stops_resubscribing_after_an_address_leaves
    WebMock.enable_net_connect!
    walter = Eth::Key.new(priv: WALTER).address.to_s.downcase
    addresses = [Eth::Key.new(priv: JEFF).address.to_s.downcase, walter]
    subscribes = 0
    on_websockets(confirmations) do |wallet, received|
      active = []
      daemon =
        Thread.new do
          wallet.accept(addresses, active, subscription_id: 42) { |event| event }
        end
      wait_for(10) { active.size == 2 }
      addresses.delete(walter)
      sleep(4)
      daemon.kill
      daemon.join(30)
      subscribes = File.readlines(received).count { |line| JSON.parse(line)['method'] == 'eth_subscribe' }
    end
    assert_equal(2, subscribes)
  end

  def test_yields_a_complete_payment
    WebMock.enable_net_connect!
    event = nil
    on_websockets([[{ jsonrpc: '2.0', id: 42, result: '0x42' }, transfer(555, false)]]) do |wallet|
      daemon =
        Thread.new do
          wallet.accept([Eth::Key.new(priv: WALTER).address.to_s.downcase], [], subscription_id: 42) do |e|
            event = e
          end
        end
      wait_for(10) { event }
      daemon.kill
      daemon.join(30)
    end
    assert_equal(
      {
        amount: 555,
        block: 16,
        from: Eth::Key.new(priv: JEFF).address.to_s.downcase,
        index: 3,
        to: Eth::Key.new(priv: WALTER).address.to_s.downcase,
        txn: "0x#{'e' * 64}"
      },
      event
    )
  end

  def test_complains_when_the_block_fails
    WebMock.enable_net_connect!
    buf = Loog::Buffer.new
    on_websockets([[{ jsonrpc: '2.0', id: 42, result: '0x42' }, transfer(777, false)]], log: buf) do |wallet|
      daemon =
        Thread.new do
          wallet.accept([Eth::Key.new(priv: WALTER).address.to_s.downcase], [], subscription_id: 42) do |_|
            raise(StandardError, 'The database is down')
          end
        end
      wait_for(10) { buf.to_s.include?('is lost') }
      daemon.kill
      daemon.join(30)
    end
    assert_match(/#{'e' * 64}, the event is lost/, buf.to_s, 'A lost payment cannot stay unnamed in the log')
  end

  def reconnection
    [
      [{ jsonrpc: '2.0', id: 'echo', result: '0xaaa' }, transfer(555, false)],
      [{ jsonrpc: '2.0', id: 'echo', result: [to_log(888, block: '0x20', index: '0x1')] }]
    ]
  end

  def test_asks_for_the_logs_of_the_gap
    WebMock.enable_net_connect!
    sent = []
    on_websockets(reconnection) do |wallet, received, reboot|
      events = []
      daemon =
        Thread.new do
          wallet.accept([Eth::Key.new(priv: WALTER).address.to_s.downcase], [], subscription_id: 42) do |e|
            events.append(e)
          end
        end
      wait_for(10) { !events.empty? }
      reboot.call
      wait_for(20) do
        sent = File.readlines(received).map { |line| JSON.parse(line) }
        sent.any? { |m| m['method'] == 'eth_getLogs' }
      end
      daemon.kill
      daemon.join(30)
    end
    assert_equal('0x11', sent.find { |m| m['method'] == 'eth_getLogs' }['params'].first['fromBlock'])
  end

  def test_yields_the_payment_missed_while_offline
    WebMock.enable_net_connect!
    missed = nil
    on_websockets(reconnection) do |wallet, _received, reboot|
      events = []
      daemon =
        Thread.new do
          wallet.accept([Eth::Key.new(priv: WALTER).address.to_s.downcase], [], subscription_id: 42) do |e|
            events.append(e)
          end
        end
      wait_for(10) { !events.empty? }
      reboot.call
      wait_for(20) { events.any? { |e| e[:amount] == 888 } }
      missed = events.find { |e| e[:amount] == 888 }
      daemon.kill
      daemon.join(30)
    end
    assert_equal(32, missed[:block], 'A payment mined during the outage cannot stay undelivered')
  end

  def rejection
    [[{ jsonrpc: '2.0', id: 42, error: { code: -32_602, message: 'too many topics' } }]]
  end

  def test_ignores_a_rejected_subscription
    WebMock.enable_net_connect!
    seen = nil
    on_websockets(rejection) do |wallet|
      active = []
      daemon =
        Thread.new do
          wallet.accept([Eth::Key.new(priv: JEFF).address.to_s.downcase], active, subscription_id: 42) { |event| event }
        end
      sleep(3)
      seen = active.to_a.dup
      daemon.kill
      daemon.join(30)
    end
    assert_empty(seen, 'Addresses cannot be active when the node rejects the subscription')
  end

  def test_retries_a_rejected_subscription
    WebMock.enable_net_connect!
    subscribes = 0
    on_websockets(rejection) do |wallet, received|
      daemon =
        Thread.new do
          wallet.accept([Eth::Key.new(priv: WALTER).address.to_s.downcase], [], subscription_id: 42) { |event| event }
        end
      sleep(4)
      daemon.kill
      daemon.join(30)
      subscribes = File.readlines(received).count { |line| JSON.parse(line)['method'] == 'eth_subscribe' }
    end
    assert_operator(subscribes, :>, 1, 'A rejected subscription cannot be the last attempt')
  end

  def test_complains_about_a_corrupt_frame
    WebMock.enable_net_connect!
    buf = Loog::Buffer.new
    on_websockets([['}not json{']], log: buf) do |wallet|
      daemon =
        Thread.new do
          wallet.accept([Eth::Key.new(priv: JEFF).address.to_s.downcase], [], subscription_id: 42) { |event| event }
        end
      wait_for(10) { buf.to_s.include?('not json') }
      daemon.kill
      daemon.join(30)
    end
    assert_match(/Failed to parse/, buf.to_s, 'A corrupt frame cannot be discarded silently')
  end

  def test_never_defaults_to_a_zero_subscription_id
    WebMock.enable_net_connect!
    seed = srand(177_660)
    sent = []
    on_websockets([[{ jsonrpc: '2.0', id: 1, result: '0x42' }]]) do |wallet, received|
      daemon =
        Thread.new do
          wallet.accept([Eth::Key.new(priv: JEFF).address.to_s.downcase]) { |event| event }
        end
      wait_for(10) { !File.readlines(received).empty? }
      sent = File.readlines(received).map { |line| JSON.parse(line)['method'] }
      daemon.kill
      daemon.join(30)
    end
    assert_includes(
      sent, 'eth_subscribe',
      'The default subscription ID cannot be a zero, which the method rejects itself'
    )
  ensure
    srand(seed)
  end

  def test_subscribes_with_a_fractional_delay
    WebMock.enable_net_connect!
    seen = []
    on_websockets([[{ jsonrpc: '2.0', id: 42, result: '0x42' }]]) do |wallet|
      active = []
      daemon =
        Thread.new do
          wallet.accept(
            [Eth::Key.new(priv: JEFF).address.to_s.downcase], active,
            delay: 0.1, subscription_id: 42
          ) { |event| event }
        end
      wait_for(10) { !active.empty? }
      seen = active.to_a.dup
      daemon.kill
      daemon.join(30)
    end
    refute_empty(seen, 'A fractional delay cannot be rejected, since the docs promise it works')
  end

  def test_rejects_an_address_without_a_prefix
    WebMock.disable_net_connect!
    wallet = ERC20::Wallet.new(host: 'example.org', log: Loog::NULL)
    assert_match(
      /Invalid format of the address/,
      assert_raises(ArgumentError) do
        Timeout.timeout(10) do
          wallet.accept([Eth::Key.new(priv: JEFF).address.to_s.downcase[2..]]) { |event| event }
        end
      end.message,
      'An address without the 0x prefix cannot monitor a different address silently'
    )
  end

  def test_rejects_a_nil_address_in_the_list
    WebMock.disable_net_connect!
    wallet = ERC20::Wallet.new(host: 'example.org', log: Loog::NULL)
    assert_match(
      /Each address must be a String/,
      assert_raises(ArgumentError) do
        Timeout.timeout(10) { wallet.accept([nil]) { |event| event } }
      end.message,
      'A nil in the list of addresses cannot reach the filter of the subscription'
    )
  end

  def test_rejects_an_address_added_at_runtime
    WebMock.enable_net_connect!
    addresses = [Eth::Key.new(priv: JEFF).address.to_s.downcase]
    crashes = []
    on_websockets(confirmations) do |wallet|
      active = []
      daemon =
        Thread.new do
          wallet.accept(addresses, active, subscription_id: 42) { |event| event }
        end
      daemon.report_on_exception = false
      wait_for(10) { !active.empty? }
      addresses.append(Eth::Key.new(priv: WALTER).address.to_s.downcase[2..])
      begin
        daemon.join(10)
      rescue ArgumentError => e
        crashes.append(e.message)
      end
      daemon.kill
    end
    assert_match(
      /Invalid format of the address/, crashes.first,
      'An address that arrives later cannot skip the check'
    )
  end

  def receipt(transfers, status: '0x1')
    {
      jsonrpc: '2.0',
      id: 42,
      result: {
        status:,
        logs: transfers.map do |amount, to|
          {
            address: ERC20::Wallet::USDT,
            data: format('0x%064x', amount),
            topics: [
              ERC20::Wallet::TRANSFER,
              "0x000000000000000000000000#{Eth::Key.new(priv: JEFF).address.to_s.downcase[2..]}",
              "0x000000000000000000000000#{to.downcase[2..]}"
            ]
          }
        end
      }
    }.to_json
  end

  def test_sums_only_transfers_to_the_receiver
    WebMock.disable_net_connect!
    walter = Eth::Key.new(priv: WALTER).address.to_s
    stub_request(:post, 'https://example.org/').to_return(
      body: receipt([[100, Eth::Key.new(priv: JEFF).address.to_s], [222, walter], [333, walter]]),
      headers: { 'Content-Type' => 'application/json' }
    )
    assert_equal(
      555,
      ERC20::Wallet.new(host: 'example.org', http_path: '/', log: Loog::NULL).sum_of("0x#{'a' * 64}", to: walter)
    )
  end

  def test_rejects_transaction_with_many_transfers
    WebMock.disable_net_connect!
    stub_request(:post, 'https://example.org/').to_return(
      body: receipt([[100, Eth::Key.new(priv: JEFF).address.to_s], [222, Eth::Key.new(priv: WALTER).address.to_s]]),
      headers: { 'Content-Type' => 'application/json' }
    )
    assert_raises(StandardError) do
      ERC20::Wallet.new(host: 'example.org', http_path: '/', log: Loog::NULL).sum_of("0x#{'a' * 64}")
    end
  end

  def test_rejects_reverted_transaction
    WebMock.disable_net_connect!
    stub_request(:post, 'https://example.org/').to_return(
      body: receipt([[100, Eth::Key.new(priv: WALTER).address.to_s]], status: '0x0'),
      headers: { 'Content-Type' => 'application/json' }
    )
    assert_raises(StandardError) do
      ERC20::Wallet.new(host: 'example.org', http_path: '/', log: Loog::NULL).sum_of("0x#{'a' * 64}")
    end
  end

  def test_rejects_amount_above_the_word_maximum
    WebMock.disable_net_connect!
    w = ERC20::Wallet.new(host: 'example.org', http_path: '/', log: Loog::NULL)
    assert_raises(ArgumentError) do
      w.pay(JEFF, Eth::Key.new(priv: WALTER).address.to_s, 2**256, limit: 60_000, price: 1000)
    end
  end

  def test_explains_why_a_huge_amount_is_rejected
    WebMock.disable_net_connect!
    w = ERC20::Wallet.new(host: 'example.org', http_path: '/', log: Loog::NULL)
    assert_match(
      /must fit into uint256/,
      assert_raises(ArgumentError) do
        w.gas_estimate(Eth::Key.new(priv: JEFF).address.to_s, Eth::Key.new(priv: WALTER).address.to_s, 2**256)
      end.message
    )
  end

  def test_encodes_the_largest_amount_in_a_single_word
    WebMock.disable_net_connect!
    data = nil
    stub_request(:post, 'https://example.org/').to_return do |request|
      data = JSON.parse(request.body)['params'].first['data']
      {
        status: 200,
        body: { jsonrpc: '2.0', id: 42, result: '0x5208' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      }
    end
    walter = Eth::Key.new(priv: WALTER).address.to_s
    ERC20::Wallet.new(host: 'example.org', http_path: '/', log: Loog::NULL).gas_estimate(
      Eth::Key.new(priv: JEFF).address.to_s, walter, (2**256) - 1
    )
    assert_equal("0xa9059cbb000000000000000000000000#{walter.downcase[2..]}#{'f' * 64}", data)
  end

  def signed
    WebMock.disable_net_connect!
    sent = []
    stub_request(:post, 'https://example.org/').to_return do |request|
      call = JSON.parse(request.body)
      sent.append(call['params'].first) if call['method'] == 'eth_sendRawTransaction'
      {
        status: 200,
        body: {
          jsonrpc: '2.0', id: call['id'],
          result:
            case call['method']
            when 'eth_getBlockByNumber' then { 'baseFeePerGas' => '0x4a817c800' }
            when 'eth_sendRawTransaction' then "0x#{'f' * 64}"
            else '0xfde8'
            end
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      }
    end
    yield(ERC20::Wallet.new(host: 'example.org', http_path: '/', log: Loog::NULL))
    Eth::Tx.decode(sent.last)
  end

  def test_pays_with_a_dynamic_fee_transaction
    assert_kind_of(
      Eth::Tx::Eip1559,
      signed { |w| w.pay(JEFF, Eth::Key.new(priv: WALTER).address.to_s, 1000) },
      'A legacy transaction gives away the entire gas price, thus it cannot be used'
    )
  end

  def test_pays_eth_with_a_dynamic_fee_txn
    assert_kind_of(
      Eth::Tx::Eip1559,
      signed { |w| w.eth_pay(JEFF, Eth::Key.new(priv: WALTER).address.to_s, 1000) },
      'A legacy transaction gives away the entire gas price, thus it cannot be used'
    )
  end

  def test_caps_the_fee_at_the_gas_price
    assert_equal(
      41_000_000_000,
      signed { |w| w.pay(JEFF, Eth::Key.new(priv: WALTER).address.to_s, 1000) }.max_fee_per_gas,
      'The doubled base fee cannot be anything but a ceiling'
    )
  end

  def test_tips_the_proposer_a_gwei
    assert_equal(
      ERC20::Wallet::GAS_PRICE_TIP,
      signed { |w| w.pay(JEFF, Eth::Key.new(priv: WALTER).address.to_s, 1000) }.max_priority_fee_per_gas,
      'The tip cannot swallow the headroom left for the growth of the base fee'
    )
  end

  def test_never_tips_above_the_fee_cap
    assert_equal(
      1000,
      signed do |w|
        w.pay(JEFF, Eth::Key.new(priv: WALTER).address.to_s, 1000, price: 1000)
      end.max_priority_fee_per_gas,
      'A tip above the fee cap cannot be accepted by any node'
    )
  end

  def test_rejects_a_nil_gas_price
    WebMock.disable_net_connect!
    w = ERC20::Wallet.new(host: 'example.org', http_path: '/', log: Loog::NULL)
    assert_match(
      /Gas price can't be nil/,
      assert_raises(ArgumentError) do
        w.eth_pay(JEFF, Eth::Key.new(priv: WALTER).address.to_s, 1000, price: nil)
      end.message,
      'A payment without a gas price cannot reach the signing of the transaction'
    )
  end

  def test_rejects_a_chain_without_a_base_fee
    WebMock.disable_net_connect!
    stub_request(:post, 'https://example.org/').to_return(
      body: { jsonrpc: '2.0', id: 42, result: { 'number' => '0x1' } }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    assert_match(
      /baseFeePerGas/,
      assert_raises(StandardError) do
        ERC20::Wallet.new(host: 'example.org', http_path: '/', log: Loog::NULL).gas_price
      end.message,
      'A chain without EIP-1559 cannot fail deep inside with an obscure message'
    )
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
