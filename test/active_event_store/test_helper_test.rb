# frozen_string_literal: true

require "test_helper"
require "active_event_store/test_helper"
require_relative "../../spec/support/test_events"

class ActiveEventStore::TestHelperTest < Minitest::Test
  include ActiveEventStore::TestHelper
  attr_reader :event_class,
    :event,
    :event2

  module TestSubscriber
    class << self
      def call(_event)
      end
    end
  end

  def setup
    super
    @event_class = ActiveEventStore::TestEvent
    @test_subscriber = TestSubscriber
    @event = event_class.new(user_id: 25, action_type: "birth")
    @event2 = event_class.new(user_id: 1, action_type: "death")
  end

  def test_assert_event_published
    events = assert_event_published(ActiveEventStore::TestEvent) do
      ActiveEventStore.publish(event)
    end

    assert events.length == 1
    assert_includes events, event
  end

  def test_assert_event_published_with_one_attribute
    assert_event_published(ActiveEventStore::TestEvent, with: {user_id: 25}) do
      ActiveEventStore.publish(event)
    end
  end

  def test_assert_event_published_with_multiple_attributes
    assert_event_published(ActiveEventStore::TestEvent, with: {user_id: 25, action_type: "birth"}) do
      ActiveEventStore.publish(event)
    end
  end

  def test_assert_event_published_with_count
    assert_event_published(ActiveEventStore::TestEvent, at_least: 2) do
      ActiveEventStore.publish(event)
      ActiveEventStore.publish(event2)
    end
  end

  # == Failure cases

  def test_assert_event_published_with_no_events
    e = assert_raises do
      assert_event_published(ActiveEventStore::TestEvent, exactly: 1) do
      end
    end

    assert_match(/exactly 1 test_event to have been published, but hasn't published anything/, e.message)
  end

  def test_assert_event_published_with_class_mismatch
    e = assert_raises do
      assert_event_published(ActiveEventStore::AnotherTestEvent) do
        ActiveEventStore.publish(event)
      end
    end

    assert_match(/at least 1 active_event_store.another_test_event to have been published.*published the following events instead/, e.message)
  end

  def test_assert_event_published_with_attribute_mismatch
    e = assert_raises do
      assert_event_published(ActiveEventStore::TestEvent, with: {user_id: 25, action_type: "death"}) do
        ActiveEventStore.publish(event)
      end
    end

    assert_match(/at least 1 test_event.*with attributes.*:user_id=>25.*:action_type=>"death".*but published(.|[\n])*:user_id=>25.*:action_type=>"birth"/s, e.message)
  end

  # == Refute tests
  def test_refute_event_published_with_published_event
    e = assert_raises do
      refute_event_published(ActiveEventStore::TestEvent, with: {user_id: 25, action_type: "birth"}) do
        ActiveEventStore.publish(event)
      end
    end

    assert_match(/at least 1 test_event not.*with attributes.*:user_id=>25.*:action_type=>"birth".*/s, e.message)
  end

  def test_refute_event_published_with_attribute_mismatched
    refute_event_published(ActiveEventStore::TestEvent, with: {user_id: 25, action_type: "death"}) do
      ActiveEventStore.publish(event)
    end
  end

  def test_refute_event_published_on_no_events
    refute_event_published(ActiveEventStore::TestEvent, with: {user_id: 25, action_type: "death"}) do
    end
  end

  # == async_subscriber tests
  def test_assert_async_event_subscriber_with_event
    ActiveEventStore.subscribe(@test_subscriber, to: event_class, sync: false)

    assert_async_event_subscriber_enqueued(@test_subscriber) do
      ActiveEventStore.publish(event)
    end
  end

  def test_assert_async_event_subscriber_raises_without_event
    ActiveEventStore.subscribe(@test_subscriber, to: event_class, sync: false)

    e = assert_raises Minitest::Assertion do
      assert_async_event_subscriber_enqueued(@test_subscriber) {}
    end

    assert_match /No enqueued job found.*job.*ActiveEventStore::TestHelperTest::TestSubscriber::SubscriberJob.*queue.*"events_subscribers"/, e.message
  end
end
