# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'eth'
require_relative 'erc20'

# The checks that every wallet makes before it touches the network.
#
# A wallet deals with private keys, public addresses, and amounts of money. A
# broken one of them either costs money or silently loses it, thus it is
# rejected the moment it arrives. Both +ERC20::Wallet+ and +ERC20::FakeWallet+
# make these very checks, so that a test that passes against the fake wallet
# doesn't fail against a real provider.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2025 Yegor Bugayenko
# License:: MIT
module ERC20::Checks
  HEX = /^0x[0-9a-fA-F]{40}$/
  private_constant :HEX

  MAX_AMOUNT = (2**256) - 1
  private_constant :MAX_AMOUNT

  private

  def to_priv(priv)
    raise(ArgumentError, 'Private key can\'t be nil') unless priv
    raise(ArgumentError, 'Private key must be a String') unless priv.is_a?(String)
    raise(ArgumentError, 'Invalid format of private key') unless /^[0-9a-fA-F]{64}$/.match?(priv)
    priv
  end

  def to_address(address)
    raise(ArgumentError, 'Address can\'t be nil') unless address
    raise(ArgumentError, 'Address must be a String') unless address.is_a?(String)
    raise(ArgumentError, 'Invalid format of the address') unless HEX.match?(address)
    address
  end

  def to_addresses(addresses)
    raise(ArgumentError, 'Addresses can\'t be nil') unless addresses
    raise(ArgumentError, 'Addresses must respond to .to_a()') unless addresses.respond_to?(:to_a)
    addresses.to_a.each do |a|
      raise(ArgumentError, 'Each address must be a String') unless a.is_a?(String)
      raise(ArgumentError, "Invalid format of the address (#{a})") unless HEX.match?(a)
    end
  end

  def to_active(active)
    raise(ArgumentError, 'Active can\'t be nil') unless active
    raise(ArgumentError, 'Active must respond to .to_a()') unless active.respond_to?(:to_a)
    raise(ArgumentError, 'Active must respond to .append()') unless active.respond_to?(:append)
    raise(ArgumentError, 'Active must respond to .clear()') unless active.respond_to?(:clear)
    active
  end

  def to_txn(txn)
    raise(ArgumentError, 'Transaction hash can\'t be nil') unless txn
    raise(ArgumentError, 'Transaction hash must be a String') unless txn.is_a?(String)
    raise(ArgumentError, 'Invalid format of the transaction hash') unless /^0x[0-9a-fA-F]{64}$/.match?(txn)
    txn
  end

  def to_amount(amount)
    raise(ArgumentError, 'Amount can\'t be nil') unless amount
    raise(ArgumentError, "Amount (#{amount}) must be an Integer") unless amount.is_a?(Integer)
    raise(ArgumentError, "Amount (#{amount}) must be a positive Integer") unless amount.positive?
    raise(ArgumentError, "Amount (#{amount}) must fit into uint256") if amount > MAX_AMOUNT
    amount
  end

  def to_limit(limit)
    raise(ArgumentError, 'Gas limit must be an Integer') unless limit.is_a?(Integer)
    least = Eth::Tx::DEFAULT_GAS_LIMIT
    raise(ArgumentError, "Gas limit #{limit} is below #{least}") if limit < least
    most = Eth::Tx::BLOCK_GAS_LIMIT
    raise(ArgumentError, "Gas limit #{limit} is above #{most}") if limit > most
    limit
  end

  def to_price(price)
    raise(ArgumentError, 'Gas price can\'t be nil') unless price
    raise(ArgumentError, 'Gas price must be an Integer') unless price.is_a?(Integer)
    raise(ArgumentError, 'Gas price must be a positive Integer') unless price.positive?
    price
  end

  def to_delay(delay)
    raise(ArgumentError, 'Delay must be a number') unless delay.is_a?(Numeric)
    raise(ArgumentError, 'Delay must be a positive number') unless delay.positive?
    delay
  end

  def to_subscription(id)
    raise(ArgumentError, 'Subscription ID must be an Integer') unless id.is_a?(Integer)
    raise(ArgumentError, 'Subscription ID must be a positive Integer') unless id.positive?
    id
  end
end
