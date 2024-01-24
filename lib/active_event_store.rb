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

    def subscribe(subscriber = nil, to: nil, sync: false, &block)
      subscriber ||= block

      to ||= infer_event_from_subscriber(subscriber) if subscriber.is_a?(Module)

      if to.nil?
        raise ArgumentError, "Couldn't infer event from subscriber. " \
                              "Please, specify event using `to:` option"
      end

      identifier =
        if to.is_a?(Class) && to <= ActiveEventStore::Event
          # register event
          mapping.register_event to

          to.identifier
        else
          to
        end

      subscriber = SubscriberJob.from(subscriber) unless sync

      event_store.subscribe subscriber, to: [identifier]
    end

    def publish(event, **options)
      event_store.publish event, **options
    end

    private

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
