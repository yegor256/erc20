# Ethereum ERC20 Manipulations in Ruby

[![DevOps By Rultor.com](https://www.rultor.com/b/yegor256/erc20)](https://www.rultor.com/p/yegor256/erc20)
[![We recommend RubyMine](https://www.elegantobjects.org/rubymine.svg)](https://www.jetbrains.com/ruby/)

[![rake](https://github.com/yegor256/erc20/actions/workflows/rake.yml/badge.svg)](https://github.com/yegor256/erc20/actions/workflows/rake.yml)
[![PDD status](https://www.0pdd.com/svg?name=yegor256/erc20)](https://www.0pdd.com/p?name=yegor256/erc20)
[![Gem Version](https://badge.fury.io/rb/erc20.svg)](https://badge.fury.io/rb/erc20)
[![Test Coverage](https://img.shields.io/codecov/c/github/yegor256/erc20.svg)](https://codecov.io/github/yegor256/erc20?branch=master)
[![Yard Docs](https://img.shields.io/badge/yard-docs-blue.svg)](https://rubydoc.info/github/yegor256/erc20/master/frames)
[![Hits-of-Code](https://hitsofcode.com/github/yegor256/erc20)](https://hitsofcode.com/view/github/yegor256/erc20)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/yegor256/erc20/blob/master/LICENSE.txt)

This small Ruby [gem](https://rubygems.org/gems/erc20)
makes manipulations with [Ethereum] [ERC20] tokens
as simple as possible, when you have a provider of
[JSON-RPC] and [WebSockets] Ethereum APIs, such as
[Infura], [GetBlock], or [Alchemy].

Install it like this:

```bash
gem install erc20
```

Or simply add this to your Gemfile:

```ruby
gem 'erc20'
```

Then, make an instance of the main class and use to read
balances, send and receive payments:

```ruby
# Create a wallet:
require 'erc20'
w = ERC20::Wallet.new(
  contract: ERC20::Wallet.USDT, # hex of it
  host: 'mainnet.infura.io',
  http_path: '/v3/<your-infura-key>',
  ws_path: '/ws/v3/<your-infura-key>',
  log: $stdout
)

# Check how many ERC20 tokens are on the given address:
usdt = w.balance(address)

# Send a few ERC20 tokens to someone and get transaction hash:
hex = w.pay(private_key, to_address, amount)

# Stay waiting, and trigger the block when new ERC20 payments show up:
addresses = ['0x...', '0x...'] # only wait for payments to these addresses
w.accept(addresses) do |event|
  puts event[:txn] # hash of transaction
  puts event[:amount] # how much, in tokens (1000000 = $1 USDT)
  puts event[:from] # who sent the payment
  puts event[:to] # who was the receiver
end
```

You can also check ETH balance and send ETH transactions:

```ruby
# Check how many ETHs are on the given address:
eth = w.eth_balance(address)

# Send a few ETHs to someone and get transaction hash:
hex = w.eth_pay(private_key, to_address, amount)
```

To check the price of a gas unit and the expected cost of a payment:

```ruby
# How many gas units required to send this payment:
units = w.gas_estimate(from, to, amount)

# What is the price of a gas unit, in gwei:
gwei = w.gas_price
```

To generate a new private key, use [eth](https://rubygems.org/gems/eth):

```ruby
require 'eth'
key = Eth::Key.new.private_hex
```

To convert a private key to a public address:

```ruby
public_hex = Eth::Key.new(priv: key).address
```

To connect to the server via [HTTP proxy] with [basic authentication]:

```ruby
w = ERC20::Wallet.new(
  host: 'go.getblock.io',
  http_path: '/<your-rpc-getblock-key>',
  ws_path: '/<your-ws-getblock-key>',
  proxy: 'http://jeffrey:swordfish@example.com:3128' # here!
)
```

You can use [squid-proxy] [Docker] image to set up your own [HTTP proxy] server.

Of course, this library works with [Polygon], [Optimism],
and other [EVM] compatible blockchains.

## How to use in command line

This gem also provides a command line tool for sending ETH and ERC20 payments
and checking balances.

First, you install it, via [gem]:

```bash
gem install erc20
```

Then, run it:

```bash
erc20 help
```

Usage should be straightforward. If you have questions, please submit an issue.

## How to use in tests

You can use the `ERC20::FakeWallet` class that behaves exactly like
`ERC20::Wallet`, but doesn't make any network connections to the provider.
Additionally, it records all requests sent to it:

```ruby
require 'erc20'
w = ERC20::FakeWallet.new
w.pay(priv, address, 42_000)
assert w.history.include?({ method: :pay, priv:, address:, amount: 42_000 })
```

## How to contribute

Read
[these guidelines](https://www.yegor256.com/2014/04/15/github-guidelines.html).
Make sure your build is green before you contribute
your pull request. You will need to have
[Ruby](https://www.ruby-lang.org/en/) 3.2+ and
[Bundler](https://bundler.io/) installed. Then:

```bash
bundle update
bundle exec rake
```

If it's clean and you don't see any error messages, submit your pull request.

[gem]: https://github.com/rubygems/rubygems
[Ethereum]: https://en.wikipedia.org/wiki/Ethereum
[ERC20]: https://ethereum.org/en/developers/docs/standards/tokens/erc-20/
[JSON-RPC]: https://ethereum.org/en/developers/docs/apis/json-rpc/
[Websockets]: https://ethereum.org/en/developers/tutorials/using-websockets/
[Infura]: https://infura.io/
[Alchemy]: https://alchemy.com/
[GetBlock]: https://getblock.io/
[basic authentication]: https://en.wikipedia.org/wiki/Basic_access_authentication
[HTTP proxy]: https://en.wikipedia.org/wiki/Proxy_server
[squid-proxy]: https://github.com/yegor256/squid-proxy
[Docker]: https://www.docker.com/
[Polygon]: https://polygon.technology/
[Optimism]: https://www.optimism.io/
[EVM]: https://ethereum.org/developers/docs/evm/
