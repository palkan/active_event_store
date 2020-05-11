# frozen_string_literal: true

module ActiveEventStore
  # RES event wrapper
  class Event < RubyEventStore::Event
    RESERVED_ATTRIBUTES = %i[event_id type metadata].freeze

    class << self
      attr_writer :identifier

      def identifier
        return @identifier if instance_variable_defined?(:@identifier)

        @identifier = name.underscore.tr("/", ".")
      end

      # define store readers
      def attributes(*fields)
        fields.each do |field|
          raise ArgumentError, "#{field} is reserved" if RESERVED_ATTRIBUTES.include?(field)

          defined_attributes << field

          class_eval <<~CODE, __FILE__, __LINE__ + 1
            def #{field}
              data[:#{field}]
            end
          CODE
        end
      end

      def sync_attributes(*fields)
        fields.each do |field|
          raise ArgumentError, "#{field} is reserved" if RESERVED_ATTRIBUTES.include?(field)

          defined_sync_attributes << field

          attr_reader field
        end
      end

      def defined_attributes
        return @defined_attributes if instance_variable_defined?(:@defined_attributes)

        @defined_attributes =
          if superclass.respond_to?(:defined_attributes)
            superclass.defined_attributes.dup
          else
            []
          end
      end

      def defined_sync_attributes
        return @defined_sync_attributes if instance_variable_defined?(:@defined_sync_attributes)

        @defined_sync_attributes =
          if superclass.respond_to?(:defined_sync_attributes)
            superclass.defined_sync_attributes.dup
          else
            []
          end
      end
    end

    def initialize(metadata: {}, event_id: nil, **params)
      validate_attributes!(params)
      extract_sync_attributes!(params)
      super(**{event_id: event_id, metadata: metadata, data: params}.compact)
    end

    # RES 0.44+
    # https://github.com/RailsEventStore/rails_event_store/pull/724
    if method_defined?(:event_type)
      def event_type
        self.class.identifier
      end
    else
      def type
        self.class.identifier
      end

      alias event_type type
    end

    def inspect
      "#{self.class.name}<#{event_type}##{message_id}>, data: #{data}, metadata: #{metadata}"
    end

    # Has been removed from RES: https://github.com/RailsEventStore/rails_event_store/pull/726
    def to_h
      {
        event_id: event_id,
        metadata: metadata.to_h,
        data: data,
        type: event_type
      }
    end

    protected

    attr_writer :event_id

    def validate_attributes!(params)
      unknown_fields = params.keys.map(&:to_sym) - self.class.defined_attributes - self.class.defined_sync_attributes
      unless unknown_fields.empty?
        raise ArgumentError, "Unknown event attributes: #{unknown_fields.join(", ")}"
      end
    end

    def extract_sync_attributes!(params)
      params.keys.each do |key|
        next unless self.class.defined_sync_attributes.include?(key.to_sym)

        instance_variable_set(:"@#{key}", params.delete(key))
      end
    end
  end
end
