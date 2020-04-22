# frozen_string_literal: true

require "rails_helper"

describe "sync #subscribe" do
  let(:event_class) { ActiveEventStore::TestEvent }

  it "subscribe with block" do
    events_seen = []

    ActiveEventStore.subscribe(to: event_class, sync: true) do |event|
      events_seen << event
    end

    event = event_class.new(user_id: 0)

    ActiveEventStore.publish event

    expect(events_seen.size).to eq 1
    expect(events_seen.last).to eq event

    event2 = event_class.new(user: {name: "Jack"}, action_type: "leave")
    ActiveEventStore.publish event2

    expect(events_seen.size).to eq 2
    expect(events_seen.last).to eq event2
  end

  it "subscribe with callable using identifier" do
    callables = 2.times.map do
      Module.new do
        class << self
          def events
            @events ||= []
          end

          def call(event)
            events << event
          end
        end
      end
    end

    callables.each do |callable|
      ActiveEventStore.subscribe(callable, to: "test_event", sync: true)
    end

    event = event_class.new(user_id: 0)

    ActiveEventStore.publish event

    callables.each do |callable|
      expect(callable.events.size).to eq 1
      expect(callable.events.last).to eq event
    end

    event2 = event_class.new(user_id: 42, action_type: "leave")
    ActiveEventStore.publish event2

    callables.each do |callable|
      expect(callable.events.size).to eq 2
      expect(callable.events.last).to eq event2
    end
  end
end
