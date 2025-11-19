# frozen_string_literal: true

# Monkey-patch event store to add `#reset!` method
# to remove all subscriptions

module RubyEventStore
  class Client
    def reset!
      broker = @broker
      broker = broker.send(:broker) if broker.is_a?(RubyEventStore::InstrumentedBroker)
      broker.instance_variable_set(:@subscriptions, RubyEventStore::Subscriptions.new)
    end
  end
end
