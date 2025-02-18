# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

$stdout.sync = true

require 'simplecov'
SimpleCov.external_at_exit = true
SimpleCov.start

require 'simplecov-cobertura'
SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter

require 'minitest/autorun'

require 'minitest/reporters'
Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new]

# To make tests retry on failure:
if ENV['RAKE']
  require 'minitest/retry'
  Minitest::Retry.use!(methods_to_skip: [])
end

# Primitive array.
class Primitivo
  def initialize(array)
    @array = array
  end

  def to_a
    @array.to_a
  end

  def append(item)
    @array.append(item)
  end
end

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2025 Yegor Bugayenko
# License:: MIT
class Minitest::Test
  def loog
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
end
