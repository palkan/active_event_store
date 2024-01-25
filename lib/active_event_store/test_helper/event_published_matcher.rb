# frozen_string_literal: true

module ActiveEventStore
  module TestHelper
    class EventPublishedMatcher
      attr_reader :attributes,
        :matching_events

      def initialize(expected_event_class, store: nil, with: nil, exactly: nil, at_least: nil, at_most: nil, refute: false)
        @event_class = expected_event_class
        @store = store || ActiveEventStore.event_store
        @attributes = with
        @refute = refute

        count_expectations = {
          exactly: exactly,
          at_most: at_most,
          at_least: at_least
        }.reject { |_, v| v.nil? }

        if count_expectations.length > 1
          raise ArgumentError("Only one of :exactly, :at_least or :at_most can be specified")
        elsif count_expectations.length == 0
          @count_expectation_kind = :at_least
          @expected_count = 1
        else
          @count_expectation_kind = count_expectations.keys.first
          @expected_count = count_expectations.values.first
        end
      end

      def with_published_events(&block)
        original_count = @store.read.count
        block.call
        in_block_events(original_count, @store.read.count)
      end

      def matches?(block)
        raise ArgumentError, "#{assertion_name} only support block assertions" if block.nil?

        events = with_published_events do
          block.call
        end

        @matching_events, @unmatching_events = partition_events(events)

        mismatch_message = count_mismatch_message(@matching_events.size)

        if mismatch_message
          expectations = [
            "Expected #{mismatch_message} #{@event_class.identifier}"
          ]

          expectations << if refute?
            report_events = @matching_events
            "not to have been published"
          else
            report_events = @unmatching_events
            "to have been published"
          end

          expectations << "with attributes #{attributes.inspect}" unless attributes.nil?

          expectations << expectations.pop + ", but"

          expectations << if report_events.any?
            report_events.inject("published the following events instead:") do |msg, event|
              msg + "\n  #{event.inspect}"
            end
          else
            "hasn't published anything"
          end

          return expectations.join(" ")
        end

        nil
      end

      private

      def refute?
        @refute
      end

      def assertion_name
        if refute?
          "refute_event_published"
        else
          "assert_event_published"
        end
      end

      def negate_on_refute(cond)
        if refute?
          !cond
        else
          cond
        end
      end

      def in_block_events(before_block_count, after_block_count)
        count_difference = after_block_count - before_block_count
        if count_difference.positive?
          @store.read.backward.limit(count_difference).to_a
        else
          []
        end
      end

      # Partitions events into matching and unmatching
      def partition_events(events)
        events.partition { |e| self.class.event_matches?(@event_class, @attributes, e) }
      end

      def count_mismatch_message(actual_count)
        case @count_expectation_kind
        when :exactly
          if negate_on_refute(actual_count != @expected_count)
            "exactly #{@expected_count}"
          end
        when :at_most
          if negate_on_refute(actual_count > @expected_count)
            "at most #{@expected_count}"
          end
        when :at_least
          if negate_on_refute(actual_count < @expected_count)
            "at least #{@expected_count}"
          end
        else
          raise ArgumentError, "Unrecognized expectation kind: #{@count_expectation_kind}"
        end
      end

      class << self
        def event_matches?(event_class, attributes, event)
          event_type_matches?(event_class, event) && event_data_matches?(attributes, event)
        end

        def event_type_matches?(event_class, event)
          event_class.identifier == event.event_type
        end

        def event_data_matches?(attributes, event)
          attributes.nil? || attributes.all? { |k, v| v == event.public_send(k) }
        end
      end
    end
  end
end
