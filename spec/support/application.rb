# frozen_string_literal: true

require "combustion"

require "rails_event_store"
require "rails/generators"

APP_ROOT = File.expand_path(File.join(__dir__, "..", "internal"))

FileUtils.rm_rf File.join(APP_ROOT, "db", "migrate")

begin
  Combustion.initialize! :active_record, :active_job do
    config.load_defaults Rails::VERSION::STRING.to_f
    config.logger = Logger.new(nil)
    config.log_level = :fatal
    config.active_job.queue_adapter = :test
  end
rescue => e
  # Fail fast if application couldn't be loaded
  $stdout.puts "Failed to load the app: #{e.message}\n#{e.backtrace.take(5).join("\n")}"
  exit(1)
end

Dir.chdir(APP_ROOT) do
  if RubyEventStore::VERSION >= "3.0.0"
    Rails::Generators.invoke("ruby_event_store:active_record:migration")
  else
    Rails::Generators.invoke("rails_event_store_active_record:migration")
  end
end

if Rails::VERSION::MAJOR > 6
  ActiveRecord::MigrationContext.new(
    File.join(APP_ROOT, "db/migrate")
  ).migrate
else
  ActiveRecord::MigrationContext.new(
    File.join(APP_ROOT, "db/migrate"),
    ActiveRecord::SchemaMigration
  ).migrate
end
