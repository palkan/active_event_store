# frozen_string_literal: true

require "rails_helper"

describe "RSpec matchers" do
  let(:event_class) { ActiveEventStore::TestEvent }
  let(:event) { event_class.new(user_id: 25, action_type: "birth") }
  let(:event2) { event_class.new(user_id: 1, action_type: "death") }

  describe "#have_published_event" do
    context "success" do
      specify "with only event class" do
        expect { ActiveEventStore.publish event }
          .to have_published_event(event_class)
      end

      specify "with event class and one attribute" do
        expect { ActiveEventStore.publish event }
          .to have_published_event(event_class).with(user_id: 25)
      end

      specify "with event class and many attributes" do
        expect { ActiveEventStore.publish event }
          .to have_published_event(event_class).with(user_id: 25, action_type: "birth")
      end

      specify "with times modifier" do
        expect do
          ActiveEventStore.publish event
          ActiveEventStore.publish event2
        end.to have_published_event(event_class).twice
      end
    end

    context "failure" do
      specify "no events published" do
        expect do
          expect { true }
            .to have_published_event(event_class)
        end.to raise_error(/to publish test_event.+exactly once, but haven't published anything/)
      end

      specify "class doesn't match" do
        expect do
          expect { ActiveEventStore.publish event }
            .to have_published_event(ActiveEventStore::AnotherTestEvent)
        end.to raise_error(/to publish active_event_store.another_test_event.+exactly once, but/)
      end

      specify "attributes don't match" do
        expect do
          expect { ActiveEventStore.publish event }
            .to have_published_event(event_class).with(user_id: 25, action_type: "death")
        end.to raise_error(/to publish test_event.+exactly once, but/)
      end

      specify "not_to published" do
        expect do
          expect { ActiveEventStore.publish event }
            .not_to have_published_event(event_class)
        end.to raise_error(/not to publish test_event/)
      end
    end
  end

  describe "#have_async_enqueued_subscriber_for" do
    before do
      ActiveEventStore::TestSubscriber =
        Module.new do
          class << self
            def call(_event)
            end
          end
        end
    end

    after do
      ActiveEventStore.send(:remove_const, :TestSubscriber) if
        ActiveEventStore.const_defined?(:TestSubscriber)
    end

    let(:subscriber_class) { ActiveEventStore::TestSubscriber }

    specify "success" do
      ActiveEventStore.subscribe(subscriber_class, to: event_class)

      expect { ActiveEventStore.publish event }
        .to have_enqueued_async_subscriber_for(subscriber_class)
    end

    specify "success with event" do
      ActiveEventStore.subscribe(subscriber_class, to: event_class)

      expect { ActiveEventStore.publish event }
        .to have_enqueued_async_subscriber_for(subscriber_class).with(event)
    end

    specify "failure when no async subscribers" do
      ActiveEventStore.subscribe(subscriber_class, to: event_class, sync: true)

      expect do
        expect { ActiveEventStore.publish event }
          .to have_enqueued_async_subscriber_for(subscriber_class)
      end.to raise_error(/no such async subscriber: ActiveEventStore::TestSubscriber/i)
    end

    specify "failure when wrong event type" do
      ActiveEventStore.subscribe(subscriber_class, to: event_class)

      expect do
        expect { ActiveEventStore.publish event }
          .to have_enqueued_async_subscriber_for(subscriber_class).with(event2)
      end.to raise_error(/expected to enqueue/)
    end

    specify "failure when wrong event data" do
      ActiveEventStore.subscribe(subscriber_class, to: event_class)

      expect do
        expect { ActiveEventStore.publish event }
          .to have_enqueued_async_subscriber_for(subscriber_class).with(event_class.new(user_id: 25, action_type: "death"))
      end.to raise_error(/expected to enqueue/)
    end
  end
end
