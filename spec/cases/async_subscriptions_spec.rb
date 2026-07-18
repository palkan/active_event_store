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

  it "enqueues job with a delay when `wait:` is given" do
    freeze_time do
      ActiveEventStore.subscribe(callable, to: event_class, wait: 10.minutes)

      expect do
        ActiveRecord::Base.transaction do
          ActiveEventStore.publish(event)
        end
      end.to have_enqueued_job.at(10.minutes.from_now)
    end
  end

  it "enqueues job at a specific time when `wait_until:` is given" do
    freeze_time do
      target = 1.hour.from_now
      ActiveEventStore.subscribe(callable, to: event_class, wait_until: target)

      expect do
        ActiveRecord::Base.transaction do
          ActiveEventStore.publish(event)
        end
      end.to have_enqueued_job.at(target)
    end
  end

  it "raises when `wait:` is combined with `sync: true`" do
    expect do
      ActiveEventStore.subscribe(callable, to: event_class, sync: true, wait: 10.minutes)
    end.to raise_error(ArgumentError, /only supported for async/)
  end

  it "raises at the subscription site when `wait:` is not a duration or number" do
    expect do
      ActiveEventStore.subscribe(callable, to: event_class, wait: -> { 10.minutes })
    end.to raise_error(ArgumentError, /`wait:` must be a number of seconds or an ActiveSupport::Duration/)
  end

  it "accepts an integer number of seconds for `wait:`" do
    freeze_time do
      ActiveEventStore.subscribe(callable, to: event_class, wait: 90)

      expect do
        ActiveRecord::Base.transaction do
          ActiveEventStore.publish(event)
        end
      end.to have_enqueued_job.at(90.seconds.from_now)
    end
  end

  it "raises at the subscription site when `wait_until:` is not a time" do
    expect do
      ActiveEventStore.subscribe(callable, to: event_class, wait_until: "tomorrow")
    end.to raise_error(ArgumentError, /`wait_until:` must be a time/)
  end

  context "when subscriber is a Class" do
    context "when call is a class method" do
      let(:callable) {
        ActiveEventStore::TestSubscriber = Class.new do
          class << self
            attr_accessor :events

            def call(event)
              self.events ||= [] << event
            end
          end
        end
      }

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
    end

    context "when call is an instance method" do
      let(:callable) {
        ActiveEventStore::TestSubscriber = Class.new do
          class << self
            attr_accessor :events
          end

          def call(event)
            self.class.events ||= [] << event
          end
        end
      }

      it "calls subscriber instance when performed", active_job: :perform do
        ActiveEventStore.subscribe(callable, to: event_class)

        ActiveRecord::Base.transaction do
          ActiveEventStore.publish(event)
        end

        expect(callable.events.size).to eq 1
        expect(callable.events.last.message_id).to eq event.message_id
        expect(callable.events.last.user).to be_nil
        expect(callable.events.last.user_id).to eq 0
      end
    end
  end
end
