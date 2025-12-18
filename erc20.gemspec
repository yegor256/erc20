# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'English'
require_relative 'lib/erc20/erc20'

Gem::Specification.new do |s|
  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=
  s.required_ruby_version = '~>3.0'
  s.name = 'erc20'
  s.version = ERC20::VERSION
  s.license = 'MIT'
  s.summary = 'Sending and receiving ERC20 tokens in Ethereum network'
  s.description =
    'A simple library for making ERC20 manipulations as easy as they ' \
    'can be for cryptocurrency newbies: checking balance, sending payments, ' \
    'and monitoring addresses for incoming payments. The library expects ' \
    'Ethereum node to provide JSON RPC and Websockets API.'
  s.authors = ['Yegor Bugayenko']
  s.email = 'yegor256@gmail.com'
  s.homepage = 'https://github.com/yegor256/erc20.rb'
  s.files = `git ls-files | grep -v -E '^(test/|\\.|renovate)'`.split($RS)
  s.rdoc_options = ['--charset=UTF-8']
  s.executables = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.extra_rdoc_files = ['README.md', 'LICENSE.txt']
  s.add_dependency 'elapsed', '~>0.2'
  s.add_dependency 'eth', '~>0.5'
  s.add_dependency 'faye-websocket', '~>0.11'
  s.add_dependency 'json', '~>2.10'
  s.add_dependency 'jsonrpc-client', '~>0.1'
  s.add_dependency 'loog', '~>0.4'
  s.add_dependency 'slop', '~>4.0'
  s.metadata['rubygems_mfa_required'] = 'true'
end
