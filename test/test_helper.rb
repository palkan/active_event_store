# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

ENV["RAILS_ENV"] = "test"

begin
  require "debug" unless ENV["CI"]
rescue LoadError
end

# https://github.com/rails/rails/issues/54263

require "logger"

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
