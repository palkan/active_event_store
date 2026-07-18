# frozen_string_literal: true

require "rails_event_store"

require "active_event_store/version"

require "active_event_store/config"
require "active_event_store/domain_event"
require "active_event_store/event"
require "active_event_store/mapping"
require "active_event_store/mapper"

require "active_event_store/rspec" if defined?(RSpec::Core)

module ActiveEventStore
  class << self
    # Underlying RailsEventStore
    attr_accessor :event_store

    def mapping
      @mapping ||= Mapping.new
    end

    def config
      @config ||= Config.new
    end

    def subscribe(subscriber = nil, to: nil, sync: false, wait: nil, wait_until: nil, &block)
      subscriber ||= block

      to ||= infer_event_from_subscriber(subscriber) if subscriber.is_a?(Module)

      if to.nil?
        raise ArgumentError, "Couldn't infer event from subscriber. " \
                              "Please, specify event using `to:` option"
      end

      assert_valid_enqueue_options!(sync: sync, wait: wait, wait_until: wait_until)

      identifier =
        if to.is_a?(Class) && to <= ActiveEventStore::Event
          # register event
          mapping.register_event to

          to.identifier
        else
          to
        end

      unless sync
        subscriber = SubscriberJob.from(subscriber)

        # Defer the subscriber job by passing Active Job's own scheduling options
        # through `.set`. The resulting ConfiguredJob is dispatched via
        # `perform_later`, so the delay is applied when the event is published.
        enqueue_options = {wait: wait, wait_until: wait_until}.compact
        subscriber = subscriber.set(**enqueue_options) unless enqueue_options.empty?
      end

      event_store.subscribe subscriber, to: [identifier]
    end

    def publish(event, **options)
      event_store.publish event, **options
    end

    private

    # `wait:`/`wait_until:` are forwarded to Active Job's `.set` verbatim, and it
    # does not evaluate callables — validate here so a bad value fails at the
    # subscription site instead of deep inside job dispatch, long after this ran.
    def assert_valid_enqueue_options!(sync:, wait:, wait_until:)
      return unless wait || wait_until

      if sync
        raise ArgumentError, "`wait:`/`wait_until:` are only supported for async subscribers"
      end

      if wait && !(wait.is_a?(Numeric) || wait.is_a?(ActiveSupport::Duration))
        raise ArgumentError, "`wait:` must be a number of seconds or an ActiveSupport::Duration (e.g. `10.minutes`), got #{wait.class}"
      end

      if wait_until && !wait_until.acts_like?(:time)
        raise ArgumentError, "`wait_until:` must be a time (e.g. `1.hour.from_now`), got #{wait_until.class}"
      end
    end

    def infer_event_from_subscriber(subscriber)
      event_class_name = subscriber.name.split("::").yield_self do |parts|
        # handle explicti top-level name, e.g. ::Some::Event
        parts.shift if parts.first.empty?
        # drop last part – it's a unique subscriber name
        parts.pop

        parts.last.sub!(/^On/, "")

        parts.join("::")
      end

      event_class_name.safe_constantize
    end
  end
end

require "active_event_store/engine"
