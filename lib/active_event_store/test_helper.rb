# frozen_string_literal: true

require "active_event_store/test_helper/event_published_matcher"

module ActiveEventStore
  module TestHelper
    extend ActiveSupport::Concern

    included do
      include ActiveJob::TestHelper
    end

    # Asserts that the given event was published `exactly`, `at_least` or `at_most` number of times
    # to a specific `store` `with` a particular hash of attributes.
    def assert_event_published(expected_event, store: nil, with: nil, exactly: nil, at_least: nil, at_most: nil, &block)
      matcher = EventPublishedMatcher.new(
        expected_event,
        store: store,
        with: with,
        exactly: exactly,
        at_least: at_least,
        at_most: at_most
      )

      if (msg = matcher.matches?(block))
        fail(msg)
      end

      matcher.matching_events
    end

    # Asserts that the given event was *not* published `exactly`, `at_least` or `at_most` number of times
    # to a specific `store` `with` a particular hash of attributes.
    def refute_event_published(expected_event, store: nil, with: nil, exactly: nil, at_least: nil, at_most: nil, &block)
      matcher = EventPublishedMatcher.new(
        expected_event,
        store: store,
        with: with,
        exactly: exactly,
        at_least: at_least,
        at_most: at_most,
        refute: true
      )

      if (msg = matcher.matches?(block))
        fail(msg)
      end
    end

    def assert_async_event_subscriber_enqueued(subscriber_class, event: nil, queue: "events_subscribers", &block)
      subscriber_job = ActiveEventStore::SubscriberJob.for(subscriber_class)
      if subscriber_job.nil?
        fail("No such async subscriber: #{subscriber_class.name}")
      end

      expected_event = event
      event_matcher = ->(actual_event) { EventPublishedMatcher.event_matches?(expected_event, expected_event.data, actual_event) }

      expected_args = if expected_event
        event_matcher
      end

      assert_enqueued_with(job: subscriber_job, queue: queue, args: expected_args) do
        ActiveRecord::Base.transaction do
          block.call
        end
      end
    end
  end
end
