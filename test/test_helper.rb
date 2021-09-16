# frozen_string_literal: true

require "combustion"

require "rails_event_store"
require "rails/generators"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

ENV["RAILS_ENV"] = "test"

require "bundler"
Bundler.require :default, :test

begin
  require "pry-byebug"
rescue LoadError
end

FileUtils.rm_rf File.join(__dir__, "../spec/internal", "db", "migrate")

Dir.chdir(File.join(__dir__, "../spec/internal")) do
  Rails::Generators.invoke("rails_event_store_active_record:migration")
end

begin
  Combustion.initialize! :active_record, :active_job do
    config.logger = Logger.new(nil)
    config.log_level = :fatal
    config.active_job.queue_adapter = :test
  end
rescue => e
  # Fail fast if application couldn't be loaded
  $stdout.puts "Failed to load the app: #{e.message}\n#{e.backtrace.take(5).join("\n")}"
  exit(1)
end

require "active_event_store"

Dir["#{__dir__}/helpers/**/*.rb"].sort.each { |f| require f }
Dir["#{__dir__}/stubs/**/*.rb"].sort.each { |f| require f }

require "minitest/autorun"

class Minitest::Test
  def teardown
    # ActiveEventStore.event_store.reset!
  end
end
