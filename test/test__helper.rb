# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

$stdout.sync = true

require 'simplecov'
require 'simplecov-cobertura'
unless SimpleCov.running
  SimpleCov.command_name('test')
  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
    [
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::CoberturaFormatter
    ]
  )
  SimpleCov.minimum_coverage 90
  SimpleCov.minimum_coverage_by_file 90
  SimpleCov.start do
    add_filter 'test/'
    add_filter 'vendor/'
    add_filter 'target/'
    track_files 'lib/**/*.rb'
    track_files '*.rb'
  end
end

require 'minitest/autorun'
require 'minitest/reporters'
Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new]

# To make tests retry on failure:
if ENV['RAKE']
  require 'minitest/retry'
  Minitest::Retry.use!
end

# Primitive array.
class Primitivo
  def initialize(array)
    @array = array
  end

  def clear
    @array.clear
  end

  def to_a
    @array.to_a
  end

  def append(item)
    @array.append(item)
  end
end

require 'webmock/minitest'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2025 Yegor Bugayenko
# License:: MIT
class ERC20::Test < Minitest::Test
  def fake_loog
    ENV['RAKE'] ? Loog::ERRORS : Loog::VERBOSE
  end

  def wait_for(seconds = 30)
    start = Time.now
    loop do
      sleep(0.1)
      break if yield
      passed = Time.now - start
      raise "Giving up after #{passed} seconds of waiting" if passed > seconds
    rescue Errno::ECONNREFUSED
      retry
    end
  end

  def wait_for_port(port)
    wait_for { Typhoeus::Request.get("http://localhost:#{port}").code == 200 }
  end

  def env(var)
    key = ENV.fetch(var, nil)
    skip("The #{var} environment variable is not set") if key.nil?
    skip("The #{var} environment variable is empty") if key.empty?
    key
  end

  def mainnet
    [
      {
        host: 'mainnet.infura.io',
        http_path: "/v3/#{env('INFURA_KEY')}",
        ws_path: "/ws/v3/#{env('INFURA_KEY')}"
      },
      {
        host: 'go.getblock.io',
        http_path: "/#{env('GETBLOCK_KEY')}",
        ws_path: "/#{env('GETBLOCK_WS_KEY')}"
      }
    ].map do |server|
      ERC20::Wallet.new(
        host: server[:host],
        http_path: server[:http_path],
        ws_path: server[:ws_path],
        log: fake_loog
      )
    end.sample
  end

  def testnet
    [
      {
        host: 'sepolia.infura.io',
        http_path: "/v3/#{env('INFURA_KEY')}",
        ws_path: "/ws/v3/#{env('INFURA_KEY')}"
      },
      {
        host: 'go.getblock.io',
        http_path: "/#{env('GETBLOCK_SEPOILA_KEY')}",
        ws_path: "/#{env('GETBLOCK_SEPOILA_KEY')}"
      }
    ].map do |server|
      ERC20::Wallet.new(
        host: server[:host],
        http_path: server[:http_path],
        ws_path: server[:ws_path],
        log: fake_loog
      )
    end.sample
  end

  def through_proxy(wallet, proxy)
    ERC20::Wallet.new(
      contract: wallet.contract, chain: wallet.chain,
      host: donce_host, port: wallet.port, http_path: wallet.http_path, ws_path: wallet.ws_path,
      ssl: wallet.ssl, proxy:, log: fake_loog
    )
  end

  def via_proxy
    RandomPort::Pool::SINGLETON.acquire do |port|
      donce(
        image: 'yegor256/squid-proxy:latest',
        ports: { port => 3128 },
        env: { 'USERNAME' => 'jeffrey', 'PASSWORD' => 'swordfish' },
        root: true, log: fake_loog
      ) do
        proxy = "http://jeffrey:swordfish@localhost:#{port}"
        wait_for do
          Typhoeus::Request.get(
            'https://www.google.com/generate_204',
            proxy:, timeout: 5
          ).code == 204
        end
        yield proxy
      end
    end
  end

  def on_hardhat(port: nil, die: nil)
    RandomPort::Pool::SINGLETON.acquire do |rnd|
      port = rnd if port.nil?
      if die
        killer = [
          '&',
          'HARDHAT_PID=$!;',
          'export HARDHAT_PID;',
          'while true; do',
          "  if [ -e #{Shellwords.escape(File.join('/die', File.basename(die)))} ]; then",
          '    kill -9 "${HARDHAT_PID}";',
          '    break;',
          '  else',
          '    sleep 0.1;',
          '  fi;',
          'done'
        ].join(' ')
      end
      cmd = "npx hardhat node #{killer if die}"
      donce(
        home: File.join(__dir__, '../hardhat'),
        ports: { port => 8545 },
        volumes: die ? { File.dirname(die) => '/die' } : {},
        command: "/bin/bash -c #{Shellwords.escape(cmd)}",
        log: fake_loog
      ) do
        wait_for_port(port)
        cmd = [
          '(cat hardhat.config.js)',
          '(ls -al)',
          '(echo y | npx hardhat ignition deploy ./ignition/modules/Foo.ts --network foo --deployment-id foo)',
          '(npx hardhat ignition status foo | tail -1 | cut -d" " -f3)'
        ].join(' && ')
        contract = donce(
          home: File.join(__dir__, '../hardhat'),
          command: "/bin/bash -c #{Shellwords.escape(cmd)}",
          build_args: { 'HOST' => donce_host, 'PORT' => port },
          log: fake_loog,
          root: true
        ).split("\n").last
        wallet = ERC20::Wallet.new(
          contract:, chain: 4242,
          host: 'localhost', port:, http_path: '/', ws_path: '/', ssl: false,
          log: fake_loog
        )
        yield wallet
      end
    end
  end
end
