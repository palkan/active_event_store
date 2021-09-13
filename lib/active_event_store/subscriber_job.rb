# frozen_string_literal: true

module ActiveEventStore
  # Base job for async subscribers
  class SubscriberJob < ActiveJob::Base
    class << self
      attr_accessor :subscriber

      def from(callable)
        if callable.is_a?(Proc) || callable.name.nil?
          raise ArgumentError, "Anonymous subscribers (blocks/procs/lambdas or anonymous modules) " \
                                "could not be asynchronous (use sync: true)"
        end

        raise ArgumentError, "Async subscriber must be a module/class, not instance" unless callable.is_a?(Module)

        if callable.const_defined?("SubscriberJob", false)
          callable.const_get("SubscriberJob", false)
        else
          callable.const_set(
            "SubscriberJob",
            Class.new(self).tap do |job|
              queue_as ActiveEventStore.config.job_queue_name

              job.subscriber = callable
            end
          )
        end
      end

      def for(callable)
        raise ArgumentError, "Async subscriber must be a module/class" unless callable.is_a?(Module)

        callable.const_defined?("SubscriberJob", false) ?
          callable.const_get("SubscriberJob", false) :
          nil
      end
    end

    def perform(payload)
      event = event_store.deserialize(**payload, serializer: JSON)

      event_store.with_metadata(**event.metadata.to_h) do
        subscriber.call(event)
      end
    end

    private

    def subscriber
      self.class.subscriber
    end

    def event_store
      ActiveEventStore.event_store
    end
  end
end
