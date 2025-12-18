# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

# This module makes manipulations with Ethereum ERC20 tokens
# as simple as they can be, if you have a provider of
# JSON-RPC and WebSockets Ethereum APIs, for example
# Infura, GetBlock, or Alchemy.
#
# Start like this:
#
#  require 'erc20'
#  w = ERC20::Wallet.new(
#    host: 'mainnet.infura.io',
#    http_path: '/v3/<your-infura-key>',
#    ws_path: '/ws/v3/<your-infura-key>'
#  )
#  puts w.balance(address)
#
# This should print the balance of the ERC20 address.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2025 Yegor Bugayenko
# License:: MIT
module ERC20
  # Current version of the gem (changed by the +.rultor.yml+ on every release)
  VERSION = '0.2.5'
end
