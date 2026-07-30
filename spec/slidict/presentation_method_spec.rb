# frozen_string_literal: true

RSpec.describe Slidict::PresentationMethodRegistry do
  it "loads built-in presentation methods" do
    methods = described_class.new(include_plugins: false).all

    expect(methods.map(&:id)).to include("aidma", "desc", "fabe", "prep", "pyramid", "scqa", "sds", "taps")
    expect(methods.find { |method| method.id == "scqa" }.slides.first.title).to eq("Situation")
    expect(methods.find { |method| method.id == "sds" }.slides.map(&:title))
      .to eq(["Summary", "Details", "Summary Revisited"])
  end

  it "raises a useful error for unknown methods" do
    expect { described_class.new(include_plugins: false).fetch("unknown") }
      .to raise_error(ArgumentError, /unknown presentation method unknown/)
  end

  it "raises a clear validation error when a method id is not a string" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "invalid.yml")
      File.write(path, <<~YAML)
        id: 123
        name: Invalid
        category: test
        description: Invalid method fixture.
        suitable_for:
          - Tests
        slides:
          - title: One
            role: Test role.
            instructions: Test instructions.
        ai_instructions:
          - Test instruction.
        review_checklist:
          - Test checklist item.
      YAML

      expect { Slidict::PresentationMethod.load_file(path) }
        .to raise_error(ArgumentError, /id must be a string/)
    end
  end
end
