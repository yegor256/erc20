# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'qbash'
require 'securerandom'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2025 Yegor Bugayenko
# License:: MIT
class TestBin < ERC20::Test
  def test_prints_help
    assert_includes(qbash(bin, 'help'), 'Commands are:', 'help does not list commands')
  end

  def test_prints_version
    qbash(bin, 'version')
  end

  def test_generates_private_key
    assert_match(/^[a-f0-9]{64}$/, qbash(bin, 'key').strip, 'key is not 64 hex chars')
  end

  def test_generates_public_key
    assert_match(/^0x[a-f0-9]{40}$/, qbash(bin, 'address', qbash(bin, 'key')).strip, 'address is not valid')
  end

  def test_wrong_command
    qbash(bin, "cmd#{SecureRandom.hex(4)}", accept: [1])
  end

  def test_fetches_gas_price
    assert_match(/^[0-9]+$/, qbash(bin, 'price', '--dry').strip, 'price is not numeric')
  end

  def test_fetches_erc20_balance
    assert_match(/^[0-9]+$/, qbash(bin, 'balance', address, '--dry').strip, 'balance is not numeric')
  end

  def test_fetches_eth_balance
    assert_match(/^[0-9]+$/, qbash(bin, 'eth_balance', address, '--dry').strip, 'eth_balance is not numeric')
  end

  def test_sends_erc20_payment
    assert_match(/^0x[a-f0-9]{64}$/, qbash(bin, 'pay', pvt, address, '100', '--dry').strip, 'txn hash is not valid')
  end

  def test_sends_erc20_payment_in_usdt
    assert_match(/^0x[a-f0-9]{64}$/, qbash(bin, 'pay', pvt, address, '1.5usdt', '--dry').strip, 'txn hash is not valid')
  end

  def test_sends_erc20_payment_in_dollars
    assert_match(/^0x[a-f0-9]{64}$/, qbash(bin, 'pay', pvt, address, '\$2.50', '--dry').strip, 'txn hash is not valid')
  end

  def test_sends_eth_payment
    assert_match(
      /^0x[a-f0-9]{64}$/, qbash(bin, 'eth_pay', pvt, address, '1000', '--dry').strip,
      'txn hash is not valid'
    )
  end

  def test_sends_eth_payment_in_wei
    assert_match(
      /^0x[a-f0-9]{64}$/, qbash(bin, 'eth_pay', pvt, address, '1000wei', '--dry').strip,
      'txn hash is not valid'
    )
  end

  def test_sends_eth_payment_in_gwei
    assert_match(
      /^0x[a-f0-9]{64}$/, qbash(bin, 'eth_pay', pvt, address, '1.5gwei', '--dry').strip,
      'txn hash is not valid'
    )
  end

  def test_sends_eth_payment_in_eth
    assert_match(
      /^0x[a-f0-9]{64}$/, qbash(bin, 'eth_pay', pvt, address, '0.001eth', '--dry').strip,
      'txn hash is not valid'
    )
  end

  private

  def bin
    File.join(__dir__, '../../bin/erc20')
  end

  def pvt
    @pvt ||= qbash(bin, 'key').strip
  end

  def address
    @address ||= qbash(bin, 'address', pvt).strip
  end
end
