# frozen_string_literal: true

require "rails_helper"

describe ActiveEventStore::Event do
  let(:event_class) { ActiveEventStore::TestEvent }

  let(:event) { event_class.new(user_id: 1, action_type: "test") }

  specify do
    expect(event.user_id).to eq 1
    expect(event.action_type).to eq "test"
    expect(event.message_id).not_to be_nil
    expect(event.metadata).to be_a(RubyEventStore::Metadata)
  end

  specify "with metadata" do
    event = event_class.new(user_id: 1, metadata: {timestamp: 321})

    expect(event.user_id).to eq 1
    expect(event.action_type).to be_nil
    expect(event.message_id).not_to be_nil
    expect(event.metadata).to be_a(RubyEventStore::Metadata)
    expect(event.metadata[:timestamp]).to eq 321
  end

  describe ".identifier" do
    specify "explicit" do
      expect(ActiveEventStore::TestEvent.identifier).to eq "test_event"
    end

    specify "inferred" do
      expect(ActiveEventStore::AnotherTestEvent.identifier).to eq "active_event_store.another_test_event"
    end
  end

  describe "#to_h" do
    specify do
      expect(event.to_h).to eq(
        event_id: event.message_id,
        data: {
          user_id: 1,
          action_type: "test"
        },
        metadata: {},
        type: "test_event"
      )
    end

    specify "with sync attributes" do
      event_class.new(user_id: 1, action_type: "test", user: {name: "John"})

      expect(event.to_h).to eq(
        event_id: event.message_id,
        data: {
          user_id: 1,
          action_type: "test"
        },
        metadata: {},
        type: "test_event"
      )
    end
  end

  specify "sets event_id if event_id is provided" do
    event = event_class.new(event_id: "123", user_id: 22)
    expect(event.to_h).to eq(
      event_id: "123",
      data: {
        user_id: 22
      },
      metadata: {},
      type: "test_event"
    )
  end

  specify "raises if unknown field is passed" do
    expect { event_class.new(users_ids: [1]) }.to raise_error(
      ArgumentError, /Unknown event attributes: users_ids/
    )
  end

  specify "raises argument error if type attribute is defined" do
    expect { Class.new(described_class) { attributes :type } }.to raise_error(
      ArgumentError, /type is reserved/
    )
  end

  specify "raises argument error if event_id attribute is defined" do
    expect { Class.new(described_class) { attributes :event_id } }.to raise_error(
      ArgumentError, /event_id is reserved/
    )
  end

  specify "raises argument error if metadata attribute is defined" do
    expect { Class.new(described_class) { attributes :metadata } }.to raise_error(
      ArgumentError, /metadata is reserved/
    )
  end
end
