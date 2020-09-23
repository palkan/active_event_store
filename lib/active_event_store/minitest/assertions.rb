module ActiveEventStore
  module Minitest
    module Assertions
      def assert_published(expected_event, options = {}, &block)
        defaults = {
          store: ActiveEventStore.event_store,
          attributes: nil,
          count: 1
        }

        options = defaults.merge(options)

        original_count = options[:store].read.count
        block.call
        new_count = options[:store].read.count - original_count

        in_block_events = if new_count.positive?
          options[:store].read.backward.limit(new_count).to_a
        else
          []
        end

        attributes_match = proc do |event|
          options[:attributes].all? do |k, v|
            v == event.public_send(k)
          end
        end

        matching_events, unmatching_events = in_block_events.partition do |actual_event|
          (expected_event.identifier == actual_event.event_type) &&
            (options[:attributes].nil? || attributes_match.call(actual_event))
        end

        matching_count = matching_events.size

        expectations = []

        unless options[:attributes].nil?
          expectations << "with attributes #{mu_pp(options[:attributes])}"
        end

        expectations_string = " " + expectations.join(" ")

        case options[:count]
        when '+', :+
          assert options[:count] == matching_count, "Expected at least one #{expected_event.name} to have been published#{expectations_string}"
        else
          assert options[:count] == matching_count, "Expected #{options[:count]} #{expected_event.name} to have been published#{expectations_string}, but got #{matching_count} instead"
        end
      end
    end
  end
end
