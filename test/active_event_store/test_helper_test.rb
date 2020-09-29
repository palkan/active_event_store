require 'test_helper'
require 'active_event_store/test_helper'
require_relative '../../spec/support/test_events'

class TestHelperTest < Minitest::Test
  include ActiveEventStore::TestHelper
  attr_reader :event_class,
              :event,
              :event2

  def setup
    super
    @event_class = ActiveEventStore::TestEvent
    @event       = event_class.new(user_id: 25, action_type: "birth")
    @event2      = event_class.new(user_id: 1, action_type: "death")
  end

  def test_assert_event_published
    assert_event_published(ActiveEventStore::TestEvent) do
      ActiveEventStore.publish(event)
    end
  end

  def test_assert_event_published_with_one_attribute
    assert_event_published(ActiveEventStore::TestEvent, with: { user_id: 25 }) do
      ActiveEventStore.publish(event)
    end
  end

  def test_assert_event_published_with_multiple_attributes
    assert_event_published(ActiveEventStore::TestEvent, with: { user_id: 25, action_type: "birth" }) do
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

    assert_match /exactly 1 test_event to have been published, but hasn't published anything/, e.message
  end

  def test_assert_event_published_with_class_mismatch
    e = assert_raises do
      assert_event_published(ActiveEventStore::AnotherTestEvent) do
        ActiveEventStore.publish(event)
      end
    end

    assert_match /at least 1 active_event_store.another_test_event to have been published.*published the following events instead/, e.message
  end

  def test_assert_event_published_with_attribute_mismatch
    e = assert_raises do
      assert_event_published(ActiveEventStore::TestEvent, with: { user_id: 25, action_type: "death" }) do
        ActiveEventStore.publish(event)
      end
    end

    assert_match /at least 1 test_event.*with attributes.*:user_id=>25.*:action_type=>"death".*but published(.|[\n])*:user_id=>25.*:action_type=>"birth"/s, e.message
  end
end
