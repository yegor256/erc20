# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'qbash'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2025 Yegor Bugayenko
# License:: MIT
class TestBin < ERC20::Test
  def test_prints_help
    stdout = qbash(bin, '--help')
    assert_includes(stdout, 'Commands are:')
  end

  def test_generates_private_key
    stdout = qbash(bin, 'key')
    assert_match(/^[a-f0-9]{64}$/, stdout.strip)
  end

  def test_generates_public_key
    pvt = qbash(bin, 'key')
    stdout = qbash(bin, 'address', pvt)
    assert_match(/^0x[a-f0-9]{40}$/, stdout.strip)
  end

  def test_wrong_command
    qbash(bin, 'foo', accept: [255])
  end

  private

  def bin
    File.join(__dir__, '../../bin/erc20')
  end
end
