# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

ENV["RAILS_ENV"] = "test"

require "bundler"
Bundler.require :default, :test

begin
  require "debug" unless ENV["CI"]
rescue LoadError
end

require_relative "../spec/support/application"

require "active_event_store"

Dir["#{__dir__}/helpers/**/*.rb"].sort.each { |f| require f }
Dir["#{__dir__}/stubs/**/*.rb"].sort.each { |f| require f }

require "minitest/autorun"

class Minitest::Test
  def teardown
    # ActiveEventStore.event_store.reset!
  end
end
