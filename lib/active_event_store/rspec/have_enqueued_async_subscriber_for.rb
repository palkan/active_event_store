# frozen_string_literal: true

# Do not fail if rspec-rails is not available
begin
  require "rspec/rails"
  require "rspec/rails/matchers/active_job"
rescue LoadError
  warn "You must add `rspec-rails` to your project to use `have_enqueued_async_subscriber_for` matcher"
  return
end

module ActiveEventStore
  class HaveEnqueuedAsyncSubscriberFor < RSpec::Rails::Matchers::ActiveJob::HaveEnqueuedJob
    class EventMatcher
      include ::RSpec::Matchers::Composable

      attr_reader :event

      def initialize(event)
        @event = event
      end

      def matches?(actual_serialized)
        actual = ActiveEventStore.event_store.deserialize(
          **actual_serialized,
          serializer: ActiveEventStore.config.serializer
        )

        actual.event_type == event.event_type && data_matches?(actual.data)
      end

      def description
        "be #{event.inspect}"
      end

      private

      def data_matches?(actual)
        ::RSpec::Matchers::BuiltIn::Match.new(event.data).matches?(actual)
      end
    end

    def initialize(subscriber_class)
      subscriber_job = ActiveEventStore::SubscriberJob.for(subscriber_class)
      if subscriber_job.nil?
        raise(
          RSpec::Expectations::ExpectationNotMetError,
          "No such async subscriber: #{subscriber_class.name}"
        )
      end
      super(subscriber_job)
      on_queue("events_subscribers")
    end

    def with(event)
      super(EventMatcher.new(event))
    end

    def matches?(block)
      raise ArgumentError, "have_enqueued_async_subscriber_for only supports block expectations" unless block.is_a?(Proc)
      # Make sure that there is a transaction
      super(proc { ActiveRecord::Base.transaction(&block) })
    end
  end
end

RSpec.configure do |config|
  config.include(Module.new {
    def have_enqueued_async_subscriber_for(*args)
      ActiveEventStore::HaveEnqueuedAsyncSubscriberFor.new(*args)
    end
  })
end
