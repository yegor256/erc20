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
end
