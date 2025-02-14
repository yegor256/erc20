# frozen_string_literal: true

# Copyright (c) 2025 Yegor Bugayenko
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# This module makes manipulations with Etherium ERC20 tokens
# as simple as they can be, if you have a provider of
# JSON-RPC and WebSockets Etherium APIs, for example
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
  VERSION = '0.0.11'
end
