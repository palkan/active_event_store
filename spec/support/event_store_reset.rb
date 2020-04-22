# frozen_string_literal: true

# Monkey-patch event store to add `#reset!` method
# to remove all subscriptions

module RubyEventStore
  class Client
    def reset!
      @broker.instance_variable_set(
        :@subscriptions,
        Subscriptions.new
      )
    end
  end
end
