# frozen_string_literal: true

module ActiveEventStore
  class HavePublishedEvent < RSpec::Matchers::BuiltIn::BaseMatcher
    attr_reader :event_class, :event_store, :attributes

    def initialize(event_class)
      @event_class = event_class
      @event_store = ActiveEventStore.event_store
      set_expected_number(:exactly, 1)
    end

    def with_store(store)
      @event_store = store
      self
    end

    def with(attributes)
      @attributes = attributes
      self
    end

    def exactly(count)
      set_expected_number(:exactly, count)
      self
    end

    def at_least(count)
      set_expected_number(:at_least, count)
      self
    end

    def at_most(count)
      set_expected_number(:at_most, count)
      self
    end

    def times
      self
    end

    def once
      exactly(:once)
    end

    def twice
      exactly(:twice)
    end

    def thrice
      exactly(:thrice)
    end

    def supports_block_expectations?
      true
    end

    def matches?(block)
      raise ArgumentError, "have_published_event only supports block expectations" unless block.is_a?(Proc)

      original_count = event_store.read.count
      block.call
      new_count = event_store.read.count - original_count
      in_block_events = new_count.positive? ? event_store.read.backward.limit(new_count).to_a :
                                              []

      @matching_events, @unmatching_events =
        in_block_events.partition do |actual_event|
          (event_class.identifier == actual_event.type) &&
            (attributes.nil? || attributes_match?(actual_event))
        end

      @matching_count = @matching_events.size

      case @expectation_type
      when :exactly then @expected_number == @matching_count
      when :at_most then @expected_number >= @matching_count
      when :at_least then @expected_number <= @matching_count
      end
    end

    private

    def attributes_match?(event)
      RSpec::Matchers::BuiltIn::HaveAttributes.new(attributes).matches?(event)
    end

    def set_expected_number(relativity, count)
      @expectation_type = relativity
      @expected_number =
        case count
        when :once then 1
        when :twice then 2
        when :thrice then 3
        else Integer(count)
        end
    end

    def failure_message
      (+"expected to publish #{event_class.identifier} event").tap do |msg|
        msg << " #{message_expectation_modifier}, but"

        if @unmatching_events.any?
          msg << " published the following events:"
          @unmatching_events.each do |unmatching_event|
            msg << "\n  #{unmatching_event.inspect}"
          end
        else
          msg << " haven't published anything"
        end
      end
    end

    def failure_message_when_negated
      "expected not to publish #{event_class.identifier} event"
    end

    def message_expectation_modifier
      number_modifier = @expected_number == 1 ? "once" : "#{@expected_number} times"
      case @expectation_type
      when :exactly then "exactly #{number_modifier}"
      when :at_most then "at most #{number_modifier}"
      when :at_least then "at least #{number_modifier}"
      end
    end
  end
end

RSpec.configure do |config|
  config.include(Module.new do
    def have_published_event(*args)
      ActiveEventStore::HavePublishedEvent.new(*args)
    end
  end)
end
