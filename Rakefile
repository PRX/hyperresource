require "bundler/setup"
require "bundler/gem_tasks"
require "rake/testtask"
require "standard/rake"

task default: [:test]

Rake::TestTask.new do |t|
  t.libs << "test"
  t.libs << "test/lib"
  t.test_files = FileList["test/unit/*_test.rb"] +
    FileList["test/live/*_test.rb"]
  t.warning = !!ENV["WARNINGS"]
  t.verbose = true
end

task :test_server do
  require "rackup"
  require "./test/live/live_test_server"
  port = ENV["PORT"] || ENV["port"] || 3000
  Rackup::Handler::WEBrick.run(LiveTestServer.new, Port: port)
end
