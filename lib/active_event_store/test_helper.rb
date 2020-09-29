# frozen_string_literal: true

module ActiveEventStore
  module TestHelper

    class EventPublishedMatcher
      attr_reader :attributes

      def initialize(expected_event_class, store: nil, with: nil, exactly: nil, at_least: nil, at_most: nil, refute: false)
        @event_class = expected_event_class
        @store       = store || ActiveEventStore.event_store
        @attributes  = with
        @refute      = refute

        count_expectations = {
          exactly:  exactly,
          at_most:  at_most,
          at_least: at_least,
        }.reject { |_, v| v.nil? }

        if count_expectations.length > 1
          raise ArgumentError("Only one of :exactly, :at_least or :at_most can be specified")
        elsif count_expectations.length == 0
          @count_expectation_kind = :at_least
          @expected_count         = 1
        else
          @count_expectation_kind = count_expectations.keys.first
          @expected_count         = count_expectations.values.first
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

        matching_events, unmatching_events = partition_events(events)

        mismatch_message = count_mismatch_message(matching_events.size)

        unless mismatch_message.nil?
          expectations = [
            "Expected #{mismatch_message} #{@event_class.identifier}"
          ]

          expectations << if refute?
            "not to have been published"
          else
            "to have been published"
          end

          expectations << "with attributes #{attributes.inspect}" unless attributes.nil?

          expectations << expectations.pop + ', but'

          expectations << if unmatching_events.any?
            unmatching_events.inject("published the following events instead:") do |msg, unmatching_event|
              msg + "\n  #{unmatching_event.inspect}"
            end
          else
            "hasn't published anything"
          end

          return expectations.join(' ')
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
        events.partition do |actual_event|
          negate_on_refute((@event_class.identifier == actual_event.event_type) &&
                             (@attributes.nil? || @attributes.all? { |k, v| v == actual_event.public_send(k) }))
        end
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

    end

    # Asserts that the given event was published `exactly`, `at_least` or `at_most` number of times
    # to a specific `store` `with` a particular hash of attributes.
    def assert_event_published(expected_event, store: nil, with: nil, exactly: nil, at_least: nil, at_most: nil, &block)
      matcher = EventPublishedMatcher.new(
        expected_event,
        store:    store,
        with:     with,
        exactly:  exactly,
        at_least: at_least,
        at_most:  at_most,
      )

      if (msg = matcher.matches?(block))
        fail(msg)
      end
    end

    def refute_event_published(expected_event, store: nil, with: nil, exactly: nil, at_least: nil, at_most: nil, &block)
      matcher = EventPublishedMatcher.new(
        expected_event,
        store:    store,
        with:     with,
        exactly:  exactly,
        at_least: at_least,
        at_most:  at_most,
        refute:   true
      )

      if (msg = matcher.matches?(block))
        fail(msg)
      end
    end
  end
end
