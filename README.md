# Etherium ERC20 Manipulations in Ruby

[![DevOps By Rultor.com](http://www.rultor.com/b/yegor256/erc20)](http://www.rultor.com/p/yegor256/erc20)
[![We recommend RubyMine](https://www.elegantobjects.org/rubymine.svg)](https://www.jetbrains.com/ruby/)

[![rake](https://github.com/yegor256/erc20/actions/workflows/rake.yml/badge.svg)](https://github.com/yegor256/erc20/actions/workflows/rake.yml)
[![PDD status](http://www.0pdd.com/svg?name=yegor256/erc20)](http://www.0pdd.com/p?name=yegor256/erc20)
[![Gem Version](https://badge.fury.io/rb/erc20.svg)](http://badge.fury.io/rb/erc20)
[![Test Coverage](https://img.shields.io/codecov/c/github/yegor256/erc20.svg)](https://codecov.io/github/yegor256/erc20?branch=master)
[![Yard Docs](http://img.shields.io/badge/yard-docs-blue.svg)](http://rubydoc.info/github/yegor256/erc20/master/frames)
[![Hits-of-Code](https://hitsofcode.com/github/yegor256/erc20)](https://hitsofcode.com/view/github/yegor256/erc20)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/yegor256/erc20/blob/master/LICENSE.txt)

This small Ruby [gem](https://rubygems.org/gems/erc20)
makes manipulations with [Etherium] [ERC20] tokens
as simple as they can be, if you have a provider of
[JSON-RPC] and [WebSocket] Etherium APIs, for example
[Infura], [GetBlock], or [Alchemy]:

```ruby
# Create a wallet:
require 'erc20'
w = ERC20::Wallet.new(
  contract: ERC20::Wallet.USDT, # hex of it
  rpc: 'https://mainnet.infura.io/v3/<your-key>',
  wss: 'wss://mainnet.infura.io/v3/<your-key>',
  log: $stdout
)

# Check balance on the address:
usdt = w.balance(address)

# Send a few tokens to someone and get transaction hash:
txn = w.pay(private_key, to_address, amount)

# Stay waiting, and trigger the block when transactions arrive:
addresses = ['0x...', '0x...']
w.accept(addresses) do |event|
  puts event[:amount] # how much
  puts event[:from] # who sent the payment
  puts event[:to] # who was the receiver
end
```

To generate a new private key, use [eth](https://rubygems.org/gems/eth):

```ruby
require 'eth'
key = Eth::Key.new.private_hex
```

To get address from private one:

```ruby
public_hex = Eth::Key.new(priv: key).address
```

## How to contribute

Read
[these guidelines](https://www.yegor256.com/2014/04/15/github-guidelines.html).
Make sure you build is green before you contribute
your pull request. You will need to have
[Ruby](https://www.ruby-lang.org/en/) 3.2+ and
[Bundler](https://bundler.io/) installed. Then:

```bash
bundle update
bundle exec rake
```

If it's clean and you don't see any error messages, submit your pull request.

[Etherium]: https://en.wikipedia.org/wiki/Ethereum
[ERC20]: https://ethereum.org/en/developers/docs/standards/tokens/erc-20/
[JSON-RPC]: https://ethereum.org/en/developers/docs/apis/json-rpc/
[Websocket]: https://ethereum.org/en/developers/tutorials/using-websockets/
[Infura]: https://infura.io/
[Alchemy]: https://alchemy.com/
[GetBlock]: https://getblock.io/
