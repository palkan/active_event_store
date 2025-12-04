# frozen_string_literal: true

require "rails_helper"

describe "Rails #to_prepare" do
  let!(:event_class) { ActiveEventStore::TestEvent }

  let!(:callable) do
    ActiveEventStore::TestSubscriber =
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

  let(:event) { event_class.new(user_id: 0, user: {name: "jack"}) }
  let(:event2) { event_class.new(user_id: 1, user: {name: "jill"}) }

  after do
    ActiveEventStore.send(:remove_const, :TestSubscriber) if
      ActiveEventStore.const_defined?(:TestSubscriber)
  end

  it "reset subscribers on #to_prepare" do
    ActiveSupport.on_load :active_event_store do
      ActiveEventStore.subscribe(ActiveEventStore::TestSubscriber, to: ActiveEventStore::TestEvent, sync: true)
    end

    ActiveEventStore.publish(event)

    expect(callable.events.size).to eq 1

    Rails.application.reloader.prepare!

    ActiveEventStore.publish(event2)

    expect(callable.events.size).to eq 2
  end
end
