# frozen_string_literal: true

shared_context "active_job:perform" do
  around do |ex|
    was_perform = ActiveJob::Base.queue_adapter.perform_enqueued_jobs
    ActiveJob::Base.queue_adapter.perform_enqueued_jobs = true
    ex.run
    ActiveJob::Base.queue_adapter.perform_enqueued_jobs = was_perform
  end
end

RSpec.configure do |config|
  config.include_context "active_job:perform", active_job: :perform
end
