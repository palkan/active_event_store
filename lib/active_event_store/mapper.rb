# frozen_string_literal: true

module ActiveEventStore
  class Mapper < RubyEventStore::Mappers::PipelineMapper
    def initialize(mapping:)
      super(RubyEventStore::Mappers::Pipeline.new(
        RubyEventStore::Mappers::Transformation::SymbolizeMetadataKeys.new,
        to_domain_event: ActiveEventStore::DomainEvent.new(mapping: mapping)
      ))
    end
  end
end
