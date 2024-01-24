# frozen_string_literal: true

require "rails_helper"

describe ActiveEventStore::Mapper do
  let(:event_class) { ActiveEventStore::TestEvent }

  let(:event) { event_class.new(user_id: 1, action_type: "test", metadata: {timestamp: 321}) }
  let(:mapping) { ActiveEventStore::Mapping.new }

  subject { described_class.new(mapping: mapping) }

  describe "#event_to_record" do
    it "works", :aggregate_failures do
      record = subject.event_to_record(event)

      expect(record.event_type).to eq "test_event"
      expect(record.data).to eq({user_id: 1, action_type: "test"})
      expect(record.metadata).to eq({timestamp: 321})
      expect(record.event_id).to eq event.message_id
    end

    specify "with sync attributes" do
      event = event_class.new(user_id: 1, user: {name: "Sara"}, action_type: "test", metadata: {timestamp: 321})

      record = subject.event_to_record(event)
      expect(record.data).to eq({user_id: 1, action_type: "test"})
    end
  end

  describe "#record_to_event" do
    let(:record) { subject.event_to_record(event) }

    it "works", :aggregate_failures do
      new_event = subject.record_to_event(record)

      expect(new_event).to eq event
    end

    it "raises error if unknown event type" do
      mapper = described_class.new(mapping: ActiveEventStore::Mapping.new)

      expect { mapper.record_to_event(record) }
        .to raise_error(/don't know how to deserialize event: "test_event"/i)
    end

    it "works if mapping is added explicitly" do
      mapper = described_class.new(mapping: mapping)

      mapping.register "test_event", "ActiveEventStore::TestEvent"

      new_event = mapper.record_to_event(record)
      expect(new_event).to eq event
    end
  end
end
