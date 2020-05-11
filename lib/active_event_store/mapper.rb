# frozen_string_literal: true

require "json"

module ActiveEventStore
  using(Module.new do
    refine Hash do
      def symbolize_keys
        RubyEventStore::TransformKeys.symbolize(self)
      end
    end
  end)

  # Custom mapper for RES events.
  #
  # See https://github.com/RailsEventStore/rails_event_store/blob/v0.35.0/ruby_event_store/lib/ruby_event_store/mappers/default.rb
  class Mapper
    def initialize(mapping:, serializer: JSON)
      @serializer = serializer
      @mapping = mapping
    end

    def event_to_serialized_record(domain_event)
      # lazily add type to mapping
      # NOTE: use class name instead of a class to handle code reload
      # in development (to avoid accessing orphaned classes)
      mapping.register(domain_event.event_type, domain_event.class.name) unless mapping.exist?(domain_event.event_type)

      RubyEventStore::SerializedRecord.new(
        event_id: domain_event.event_id,
        metadata: serializer.dump(domain_event.metadata.to_h),
        data: serializer.dump(domain_event.data),
        event_type: domain_event.event_type
      )
    end

    def serialized_record_to_event(record)
      event_class = mapping.fetch(record.event_type) do
        raise "Don't know how to deserialize event: \"#{record.event_type}\". " \
              "Add explicit mapping: ActiveEventStore.mapper.register \"#{record.event_type}\", \"<Class Name>\""
      end

      Object.const_get(event_class).new(
        **serializer.load(record.data).symbolize_keys,
        metadata: serializer.load(record.metadata).symbolize_keys,
        event_id: record.event_id
      )
    end

    private

    attr_reader :serializer, :mapping
  end
end
