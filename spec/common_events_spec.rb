# frozen_string_literal: true

require "rails_helper"

describe ActiveEventStore do
  specify ".event_store" do
    expect(described_class.event_store).not_to be_nil
  end

  specify ".mapping" do
    expect(described_class.mapping).to be_a(ActiveEventStore::Mapping)
  end
end
