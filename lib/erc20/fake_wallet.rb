# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'checks'
require_relative 'erc20'
require_relative 'wallet'

# A fake wallet that behaves like a +ERC20::Wallet+.
#
# It rejects exactly what the real wallet rejects, so that a broken private
# key, address, or amount fails in a test the same way it would fail with a
# real provider, where money is at stake.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2025 Yegor Bugayenko
# License:: MIT
class ERC20::FakeWallet
  include ERC20::Checks

  TXN_HASH = '0x172de9cda30537eae68ab4a96163ebbb8f8a85293b8737dd2e5deb4714b14623'

  attr_reader :host, :port, :ssl, :chain, :contract, :ws_path, :http_path, :history

  # Ctor.
  def initialize
    @host = 'example.com'
    @port = 443
    @ssl = true
    @chain = 1
    @contract = ERC20::Wallet::USDT
    @ws_path = '/'
    @http_path = '/'
    @history = []
    @balances = {}
    @eth_balances = {}
  end

  # Set balance, to be returned by the +balance()+.
  # @param [String] address Public key, in hex, starting from '0x'
  # @param [Integer] tokens How many tokens to put there
  def set_balance(address, tokens)
    @balances[address] = tokens
  end

  # Set balance, to be returned by the +balance()+.
  # @param [String] address Public key, in hex, starting from '0x'
  # @param [Integer] wei How many wei to put there
  def set_eth_balance(address, wei)
    @eth_balances[address] = wei
  end

  # Get ERC20 balance of a public address.
  #
  # @param [String] address Public key, in hex, starting from '0x'
  # @return [Integer] Balance, in tokens
  def balance(address)
    to_address(address)
    b = @balances[address] || 42_000_000
    @history << { method: :balance, address:, result: b }
    b
  end

  # Get ETH balance of a public address.
  #
  # @param [String] address Public key, in hex, starting from '0x'
  # @return [Integer] Balance, in tokens
  def eth_balance(address)
    to_address(address)
    b = @eth_balances[address] || 77_000_000_000_000_000
    @history << { method: :eth_balance, address:, result: b }
    b
  end

  # Get ERC20 amount (in tokens) that was sent in the given transaction.
  #
  # @param [String] txn Hex of transaction
  # @param [String] to Public key of the receiver, in hex, starting from '0x'
  # @return [Integer] Amount, in ERC20 tokens
  def sum_of(txn, to: nil)
    to_txn(txn)
    to_address(to) unless to.nil?
    tokens = 42_000_000
    @history << { method: :sum_of, txn:, to:, result: tokens }
    tokens
  end

  # How many gas units are required to send an ERC20 transaction.
  #
  # @param [String] from The departing address, in hex
  # @param [String] to Arriving address, in hex
  # @param [Integer] amount How many ERC20 tokens to send
  # @return [Integer] How many gas units required
  def gas_estimate(from, to, amount)
    to_address(from)
    to_address(to)
    to_amount(amount)
    gas = 66_000
    @history << { method: :gas_estimate, from:, to:, amount:, result: gas }
    gas
  end

  # What is the price of gas unit in wei?
  #
  # The unit is the same as in +ERC20::Wallet#gas_price+: a price in gwei
  # would be a billion times smaller and would make every fee computed in a
  # test look affordable, while in production it wouldn't be.
  #
  # @return [Integer] Price of gas unit, in wei (1 gwei = 0.000000001 ETH)
  def gas_price
    wei = 55_555_000_000
    @history << { method: :gas_price, result: wei }
    wei
  end

  # Send a single ERC20 payment from a private address to a public one.
  #
  # @param [String] priv Private key, in hex
  # @param [String] address Public key, in hex
  # @param [Integer] amount The amount of ERC20 tokens to send
  # @param [Integer] limit Optional gas limit
  # @param [Integer] price The most you pay per computation unit, in wei
  # @return [String] Transaction hash
  def pay(priv, address, amount, limit: nil, price: gas_price)
    to_priv(priv)
    to_address(address)
    to_amount(amount)
    to_limit(limit) if limit
    to_price(price)
    hex = TXN_HASH
    @history << { method: :pay, priv:, address:, amount:, limit:, price:, result: hex }
    hex
  end

  # Send a single ETH payment from a private address to a public one.
  #
  # @param [String] priv Private key, in hex
  # @param [String] address Public key, in hex
  # @param [Integer] amount The amount of ETHs to send
  # @param [Integer] price The most you pay per computation unit, in wei
  # @return [String] Transaction hash
  def eth_pay(priv, address, amount, price: gas_price)
    to_priv(priv)
    to_address(address)
    to_amount(amount)
    to_price(price)
    hex = TXN_HASH
    @history << { method: :eth_pay, priv:, address:, amount:, price:, result: hex }
    hex
  end

  # Wait and accept.
  #
  # @param [Array<String>] addresses Addresses to monitor
  # @param [Array] active List of addresses that we are actually listening to
  # @param [Boolean] raw TRUE if you need to get JSON events as they arrive from Websockets
  # @param [Numeric] delay How many seconds to wait between +eth_subscribe+ calls
  # @param [Integer] subscription_id Unique ID of the subscription
  def accept(addresses, active = [], raw: false, delay: 1, subscription_id: rand(1..99_999))
    to_addresses(addresses)
    to_active(active)
    to_delay(delay)
    to_subscription(subscription_id)
    @history << { method: :accept, addresses:, active:, raw:, delay:, subscription_id: }
    addresses.to_a.each { |a| active.append(a) }
    loop do
      sleep(delay)
      to_addresses(addresses)
      a = addresses.to_a.sample
      next if a.nil?
      yield(
        if raw
          {}
        else
          {
            amount: 424_242,
            block: 42,
            from: '0xd5ff1bfcde7a03da61ad229d962c74f1ea2f16a5',
            index: 0,
            to: a,
            txn: TXN_HASH
          }
        end
      )
    end
  end
end
