# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'
require 'reek/rake/task'
require 'rubocop/rake_task'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_{spec,test}.rb']
end

desc 'Run rubocop'
task :rubocop do
  RuboCop::RakeTask.new
end

desc 'Run reek'
Reek::Rake::Task.new do |t|
  t.fail_on_error = true
end

task default: %i[test rubocop reek]
