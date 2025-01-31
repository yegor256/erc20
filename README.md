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

This small Ruby library makes Etherium ERC20 manipulations
as simple as they can be, for a cryptocurrency newbie:

```ruby
# List of private keys:
keys = ['...', '...']

# Create a wallet:
w = ERC20::Wallet.new(keys)

# Add new key and return its public address:
address = w.create

# Send a few tokens to someone:
w.send(to_address, amount)

# Stay waiting, and trigger the block when transactions arrive:
w.accept(&block)
```

That's it.

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
