# frozen_string_literal: true

require_relative "lib/active_event_store/version"

Gem::Specification.new do |s|
  s.name = "active_event_store"
  s.version = ActiveEventStore::VERSION
  s.authors = ["Vladimir Dementyev"]
  s.email = ["dementiev.vm@gmail.com"]
  s.homepage = "http://github.com/palkan/active_event_store"
  s.summary = "Rails Event Store in a more Rails way"
  s.description = "Wrapper over Rails Event Store with conventions and transparent Rails integration"

  s.metadata = {
    "bug_tracker_uri" => "http://github.com/palkan/active_event_store/issues",
    "changelog_uri" => "https://github.com/palkan/active_event_store/blob/master/CHANGELOG.md",
    "documentation_uri" => "http://github.com/palkan/active_event_store",
    "homepage_uri" => "http://github.com/palkan/active_event_store",
    "source_code_uri" => "http://github.com/palkan/active_event_store"
  }

  s.license = "MIT"

  s.files = Dir.glob("lib/**/*") + Dir.glob("bin/**/*") + %w[README.md LICENSE.txt CHANGELOG.md]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 2.6"

  s.add_dependency "rails_event_store", ">= 2.1.0"

  s.add_development_dependency "bundler", ">= 1.15"
  s.add_development_dependency "combustion", ">= 1.1"
  s.add_development_dependency "rake", ">= 13.0"
  s.add_development_dependency "rspec-rails", ">= 3.8"
  s.add_development_dependency "minitest", "~> 5.0"
end
