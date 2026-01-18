# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'erc20'
require_relative 'wallet'

# A fake wallet that behaves like a +ERC20::Wallet+.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2025 Yegor Bugayenko
# License:: MIT
class ERC20::FakeWallet
  # Transaction hash always returned:
  TXN_HASH = '0x172de9cda30537eae68ab4a96163ebbb8f8a85293b8737dd2e5deb4714b14623'

  # Fakes:
  attr_reader :host, :port, :ssl, :chain, :contract, :ws_path, :http_path

  # Full history of all method calls:
  attr_reader :history

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
    b = @balances[address] || 42_000_000
    @history << { method: :balance, address:, result: b }
    b
  end

  # Get ETH balance of a public address.
  #
  # @param [String] address Public key, in hex, starting from '0x'
  # @return [Integer] Balance, in tokens
  def eth_balance(address)
    b = @eth_balances[address] || 77_000_000_000_000_000
    @history << { method: :eth_balance, address:, result: b }
    b
  end

  # Get ERC20 amount (in tokens) that was sent in the given transaction.
  #
  # @param [String] _txn Hex of transaction
  # @return [Integer] Balance, in ERC20 tokens
  def sum_of(_txn)
    42_000_000
  end

  # How much gas units is required in order to send ERC20 transaction.
  #
  # @param [String] from The departing address, in hex
  # @param [String] to Arriving address, in hex
  # @param [Integer] amount How many ERC20 tokens to send
  # @return [Integer] How many gas units required
  def gas_estimate(from, to, amount)
    gas = 66_000
    @history << { method: :gas_estimate, from:, to:, amount:, result: gas }
    gas
  end

  # What is the price of gas unit in gwei?
  # @return [Integer] Price of gas unit, in gwei (0.000000001 ETH)
  def gas_price
    gwei = 55_555
    @history << { method: :gas_price, result: gwei }
    gwei
  end

  # Send a single ERC20 payment from a private address to a public one.
  #
  # @param [String] priv Private key, in hex
  # @param [String] address Public key, in hex
  # @param [Integer] amount The amount of ERC20 tokens to send
  # @param [Integer] limit Optional gas limit
  # @param [Integer] price Optional gas price in gwei
  # @return [String] Transaction hash
  def pay(priv, address, amount, limit: nil, price: nil)
    hex = TXN_HASH
    @history << { method: :pay, priv:, address:, amount:, limit:, price:, result: hex }
    hex
  end

  # Send a single ETH payment from a private address to a public one.
  #
  # @param [String] priv Private key, in hex
  # @param [String] address Public key, in hex
  # @param [Integer] amount The amount of ETHs to send
  # @param [Integer] price Optional gas price in gwei
  # @return [String] Transaction hash
  def eth_pay(priv, address, amount, price: nil)
    hex = TXN_HASH
    @history << { method: :eth_pay, priv:, address:, amount:, price:, result: hex }
    hex
  end

  # Wait and accept.
  #
  # @param [Array<String>] addresses Addresses to monitor
  # @param [Array] active List of addresses that we are actually listening to
  # @param [Boolean] raw TRUE if you need to get JSON events as they arrive from Websockets
  # @param [Integer] delay How many seconds to wait between +eth_subscribe+ calls
  def accept(addresses, active = [], raw: false, delay: 1)
    @history << { method: :accept, addresses:, active:, raw:, delay: }
    addresses.to_a.each { |a| active.append(a) }
    loop do
      sleep(delay)
      a = addresses.to_a.sample
      next if a.nil?
      event =
        if raw
          {}
        else
          {
            amount: 424_242,
            from: '0xd5ff1bfcde7a03da61ad229d962c74f1ea2f16a5',
            to: a,
            txn: TXN_HASH
          }
        end
      yield event
    end
  end
end
