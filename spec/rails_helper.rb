# frozen_string_literal: true

begin
  require "pry-byebug"
rescue LoadError
end

ENV["RAILS_ENV"] = "test"

require "combustion"

require "rails_event_store"
require "rails/generators"

FileUtils.rm_rf File.join(__dir__, "internal", "db", "migrate")

Dir.chdir(File.join(__dir__, "internal")) do
  Rails::Generators.invoke("rails_event_store_active_record:migration")
end

begin
  Combustion.initialize! :active_record, :active_job do
    config.logger = Logger.new(nil)
    config.log_level = :fatal
    config.active_job.queue_adapter = :test
  end
rescue => e
  # Fail fast if application couldn't be loaded
  $stdout.puts "Failed to load the app: #{e.message}\n#{e.backtrace.take(5).join("\n")}"
  exit(1)
end

require "rspec/rails"
require "active_event_store"

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].sort.each { |f| require f }

RSpec.configure do |config|
  config.mock_with :rspec

  config.example_status_persistence_file_path = "tmp/rspec_examples.txt"
  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  config.order = :random
  Kernel.srand config.seed

  config.after(:each) do
    ActiveEventStore.event_store.reset!
  end
end
