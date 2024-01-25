# frozen_string_literal: true

module ActiveEventStore
  class DomainEvent < RubyEventStore::Mappers::Transformation::DomainEvent
    attr_reader :mapping
    def initialize(mapping:)
      @mapping = mapping
    end

    def dump(event)
      # lazily add type to mapping
      # NOTE: use class name instead of a class to handle code reload
      # in development (to avoid accessing orphaned classes)
      mapping.register(event.event_type, event.class.name) unless mapping.exist?(event.event_type)

      metadata = event.metadata.dup.to_h
      timestamp = metadata[:timestamp]
      valid_at = metadata[:valid_at]
      RubyEventStore::Record.new(
        event_id: event.event_id,
        metadata: metadata,
        data: event.data,
        event_type: event.event_type,
        timestamp: timestamp,
        valid_at: valid_at
      )
    end

    def load(record)
      event_class = mapping.fetch(record.event_type) {
        raise "Don't know how to deserialize event: \"#{record.event_type}\". " \
              "Add explicit mapping: ActiveEventStore.mapping.register \"#{record.event_type}\", \"<Class Name>\""
      }

      Object
        .const_get(event_class)
        .new(
          **record.data.symbolize_keys,
          event_id: record.event_id,
          metadata: record.metadata.merge(timestamp: record.timestamp, valid_at: record.valid_at)
        )
    end
  end
end
