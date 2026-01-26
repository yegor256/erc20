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
    stdout = qbash(bin, 'help')
    assert_includes(stdout, 'Commands are:', 'help does not list commands')
  end

  def test_prints_version
    qbash(bin, 'version')
  end

  def test_generates_private_key
    stdout = qbash(bin, 'key')
    assert_match(/^[a-f0-9]{64}$/, stdout.strip, 'key is not 64 hex chars')
  end

  def test_generates_public_key
    pvt = qbash(bin, 'key')
    stdout = qbash(bin, 'address', pvt)
    assert_match(/^0x[a-f0-9]{40}$/, stdout.strip, 'address is not valid')
  end

  def test_wrong_command
    qbash(bin, "cmd#{SecureRandom.hex(4)}", accept: [1])
  end

  def test_fetches_gas_price
    stdout = qbash(bin, 'price', '--dry')
    assert_match(/^[0-9]+$/, stdout.strip, 'price is not numeric')
  end

  def test_fetches_erc20_balance
    stdout = qbash(bin, 'balance', address, '--dry')
    assert_match(/^[0-9]+$/, stdout.strip, 'balance is not numeric')
  end

  def test_fetches_eth_balance
    stdout = qbash(bin, 'eth_balance', address, '--dry')
    assert_match(/^[0-9]+$/, stdout.strip, 'eth_balance is not numeric')
  end

  def test_sends_erc20_payment
    stdout = qbash(bin, 'pay', pvt, address, '100', '--dry')
    assert_match(/^0x[a-f0-9]{64}$/, stdout.strip, 'txn hash is not valid')
  end

  def test_sends_erc20_payment_in_usdt
    stdout = qbash(bin, 'pay', pvt, address, '1.5usdt', '--dry')
    assert_match(/^0x[a-f0-9]{64}$/, stdout.strip, 'txn hash is not valid')
  end

  def test_sends_erc20_payment_in_dollars
    stdout = qbash(bin, 'pay', pvt, address, '\$2.50', '--dry')
    assert_match(/^0x[a-f0-9]{64}$/, stdout.strip, 'txn hash is not valid')
  end

  def test_sends_eth_payment
    stdout = qbash(bin, 'eth_pay', pvt, address, '1000', '--dry')
    assert_match(/^0x[a-f0-9]{64}$/, stdout.strip, 'txn hash is not valid')
  end

  def test_sends_eth_payment_in_wei
    stdout = qbash(bin, 'eth_pay', pvt, address, '1000wei', '--dry')
    assert_match(/^0x[a-f0-9]{64}$/, stdout.strip, 'txn hash is not valid')
  end

  def test_sends_eth_payment_in_gwei
    stdout = qbash(bin, 'eth_pay', pvt, address, '1.5gwei', '--dry')
    assert_match(/^0x[a-f0-9]{64}$/, stdout.strip, 'txn hash is not valid')
  end

  def test_sends_eth_payment_in_eth
    stdout = qbash(bin, 'eth_pay', pvt, address, '0.001eth', '--dry')
    assert_match(/^0x[a-f0-9]{64}$/, stdout.strip, 'txn hash is not valid')
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
