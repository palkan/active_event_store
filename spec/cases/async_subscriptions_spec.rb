# frozen_string_literal: true

require "rails_helper"

describe "async #subscribe" do
  let(:event_class) { ActiveEventStore::TestEvent }

  let(:callable) do
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

  after do
    ActiveEventStore.send(:remove_const, :TestSubscriber) if
      ActiveEventStore.const_defined?(:TestSubscriber)
  end

  it "enqueues job" do
    ActiveEventStore.subscribe(callable, to: event_class)

    expect do
      # we need to explicitly wrap `publish` in transaction
      # to make transactional_fixtures + after_commit work
      # correctly
      ActiveRecord::Base.transaction do
        ActiveEventStore.publish(event)
      end
    end.to have_enqueued_job.on_queue("events_subscribers")
  end

  it "calls subscriber when performed", active_job: :perform do
    ActiveEventStore.subscribe(callable, to: event_class)

    ActiveRecord::Base.transaction do
      ActiveEventStore.publish(event)
    end

    expect(callable.events.size).to eq 1
    expect(callable.events.last.message_id).to eq event.message_id
    expect(callable.events.last.user).to be_nil
    expect(callable.events.last.user_id).to eq 0
  end

  it "raises error when used with block" do
    expect do
      ActiveEventStore.subscribe(to: event_class) { |_| true }
    end.to raise_error(/could not be asynchronous/)
  end
end
