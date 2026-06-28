# frozen_string_literal: true

require "rails/engine"

module ActiveEventStore
  class Engine < ::Rails::Engine
    config.active_event_store = ActiveEventStore.config

    # Use before configuration hook to check for ActiveJob presence
    ActiveSupport.on_load(:before_configuration) do
      next warn "Active Job is not loaded. Active Event Store asynchronous subscriptions won't work" unless defined?(::ActiveJob)

      require "active_event_store/subscriber_job"
      require "active_event_store/rspec/have_enqueued_async_subscriber_for" if defined?(::RSpec::Matchers)
    end

    config.to_prepare do
      # `AfterCommitAsyncDispatcher` was renamed to `AfterCommitDispatcher` in
      # rails_event_store 2.19.0 and removed in 3.0.0. Both share the same
      # `scheduler:` interface, so pick whichever is available.
      after_commit_dispatcher_class =
        if defined?(RailsEventStore::AfterCommitDispatcher)
          RailsEventStore::AfterCommitDispatcher
        else
          RailsEventStore::AfterCommitAsyncDispatcher
        end

      # `RubyEventStore::Dispatcher` was renamed to `SyncScheduler` in the same
      # release (2.19.0) and removed in 3.0.0.
      sync_dispatcher =
        if defined?(RubyEventStore::SyncScheduler)
          RubyEventStore::SyncScheduler.new
        else
          RubyEventStore::Dispatcher.new
        end

      # See https://railseventstore.org/docs/subscribe/#scheduling-async-handlers-after-commit
      ActiveEventStore.event_store = RailsEventStore::Client.new(
        message_broker: RubyEventStore::Broker.new(
          dispatcher: RubyEventStore::ComposedDispatcher.new(
            after_commit_dispatcher_class.new(
              scheduler: RailsEventStore::ActiveJobScheduler.new(
                serializer: ActiveEventStore.config.serializer
              )
            ),
            sync_dispatcher
          )
        ),
        repository: ActiveEventStore.config.repository,
        mapper: ActiveEventStore::Mapper.new(mapping: ActiveEventStore.mapping),
        **ActiveEventStore.config.store_options
      )
      Rails.configuration.event_store = ActiveEventStore.event_store

      ActiveSupport.run_load_hooks(:active_event_store, ActiveEventStore)
    end
  end
end
