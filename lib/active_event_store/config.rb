# frozen_string_literal: true

module ActiveEventStore
  class Config
    attr_writer :repository, :job_queue_name, :store_options

    def repository
      @repository ||= RailsEventStoreActiveRecord::EventRepository.new
    end

    def job_queue_name
      @job_queue_name ||= :events_subscribers
    end

    def store_options
      @store_options ||= {}
    end
  end
end
