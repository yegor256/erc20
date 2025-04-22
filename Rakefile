# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'rubygems'
require 'rake'
require 'rake/clean'

ENV['RAKE'] = 'true'

def name
  @name ||= File.basename(Dir['*.gemspec'].first, '.*')
end

def version
  Gem::Specification.load(Dir['*.gemspec'].first).version
end

task default: %i[clean test features rubocop yard]

require 'rake/testtask'
desc 'Run all unit tests'
Rake::TestTask.new(:test) do |test|
  Rake::Cleaner.cleanup_files(['coverage'])
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.warning = true
  test.verbose = false
end

require 'yard'
desc 'Build Yard documentation'
YARD::Rake::YardocTask.new do |t|
  t.files = ['lib/**/*.rb']
end

require 'rubocop/rake_task'
desc 'Run RuboCop on all directories'
RuboCop::RakeTask.new(:rubocop) do |task|
  task.fail_on_error = true
end

require 'cucumber/rake/task'
Cucumber::Rake::Task.new(:features) do
  Rake::Cleaner.cleanup_files(['coverage'])
end
Cucumber::Rake::Task.new(:'features:html') do |t|
  t.profile = 'html_report'
end

desc 'Run benchmark script'
task :benchmark do
  ruby 'benchmarks/simple.rb'
end
