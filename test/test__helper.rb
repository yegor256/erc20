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
