require "json"
require "tempfile"

RSpec.configure do |config|
  # config.before { $stdout = StringIO.new }
  # config.after { $stdout = STDOUT }
end

RSpec.describe "RSpec Summary Generator" do
  let(:json_content) do
    {
      "seed" => 12345,
      "examples" => [
        {
          "id" => "./spec/example_spec.rb[1:1]",
          "description" => "passes correctly",
          "full_description" => "RSpec Summary Generator passes correctly",
          "status" => "passed",
          "file_path" => "./spec/example_spec.rb",
          "line_number" => 10,
          "run_time" => 0.5,
          "pending_message" => nil,
        },
        {
          "id" => "./spec/example_spec.rb[1:2]",
          "description" => "fails intentionally",
          "full_description" => "RSpec Summary Generator fails intentionally",
          "status" => "failed",
          "file_path" => "./spec/example_spec.rb",
          "line_number" => 15,
          "run_time" => 70.4,
          "pending_message" => nil,
          "exception" => {
            "class" => "RSpec::Expectations::ExpectationNotMetError",
            "message" => "expected: 2\n     got: 1",
          },
        },
        {
          "id" => "./spec/example_spec.rb[1:3]",
          "description" => "fails with color codes",
          "full_description" => "RSpec Summary Generator fails with color codes",
          "status" => "failed",
          "file_path" => "./spec/example_spec.rb",
          "line_number" => 16,
          "run_time" => 5.0,
          "pending_message" => nil,
          "exception" => {
            "class" => "RSpec::Expectations::ExpectationNotMetError",
            "message" => "Expected \u001b[33m\"foo\"\u001b[0m\nto include \u001b[35m\"bar\"\u001b[0m",
          },
        },
        {
          "id" => "./spec/example_spec.rb[1:4]",
          "description" => "is pending",
          "full_description" => "RSpec Summary Generator is pending",
          "status" => "pending",
          "file_path" => "./spec/example_spec.rb",
          "line_number" => 20,
          "run_time" => 0.3,
          "pending_message" => "Not implemented yet",
        },
      ],
    }.to_json
  end

  let(:json_file) do
    file = Tempfile.new([ "test_results", ".json" ])
    file.write(json_content)
    file.rewind
    file
  end

  let(:summary_file) { Tempfile.new("summary") }
  let(:output_file) { Tempfile.new("output") }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("PATTERN").and_return(json_file.path)
    allow(ENV).to receive(:[]).with("GITHUB_STEP_SUMMARY").and_return(summary_file.path)
    allow(ENV).to receive(:[]).with("GITHUB_OUTPUT").and_return(output_file.path)
    allow(ENV).to receive(:[]).with("GITHUB_SERVER_URL").and_return("https://github.com")
    allow(ENV).to receive(:[]).with("GITHUB_REPOSITORY").and_return("p-wall/rspec-summary-action")
    allow(ENV).to receive(:[]).with("GITHUB_SHA").and_return("sha")
    load "summary.rb"
  end

  it "writes the correct summary to the file" do
    summary = File.read(summary_file.path)
    expect(summary).to include("### RSpec Summary")
    expect(summary).to include("4 examples, 2 failures, 1 pending in 1m16s")
    expect(summary).to include("| [<code>spec/example_spec.rb:15</code>](https://github.com/p-wall/rspec-summary-action/blob/sha/spec/example_spec.rb#L15) | RSpec Summary Generator fails intentionally | <pre>RSpec::Expectations::ExpectationNotMetError<br />expected: 2<br />     got: 1</pre> |")
    expect(summary).to include("| [<code>spec/example_spec.rb:16</code>](https://github.com/p-wall/rspec-summary-action/blob/sha/spec/example_spec.rb#L16) | RSpec Summary Generator fails with color codes | <pre>RSpec::Expectations::ExpectationNotMetError<br />Expected \"foo\"<br />to include \"bar\"</pre> |")
    expect(summary).to include("| [<code>spec/example_spec.rb:20</code>](https://github.com/p-wall/rspec-summary-action/blob/sha/spec/example_spec.rb#L20) | RSpec Summary Generator is pending | <pre>Not implemented yet</pre> |")
    expect(summary).to include("All examples run with <code>--seed 12345</code>")
  end

  it "outputs failure information" do
    output = File.read(output_file.path)
    expect(output).to eq <<~HERE
      failing_tests<<EOF
      spec/example_spec.rb:15 - RSpec::Expectations::ExpectationNotMetError: expected: 2      got: 1
      spec/example_spec.rb:16 - RSpec::Expectations::ExpectationNotMetError: Expected "foo" to include "bar"
      EOF
    HERE
  end

  context "when there are no failures" do
    let(:json_content) do
      {
        "seed" => 12345,
        "examples" => [
          {
            "id" => "./spec/example_spec.rb[1:1]",
            "description" => "passes correctly",
            "full_description" => "RSpec Summary Generator passes correctly",
            "status" => "passed",
            "file_path" => "./spec/example_spec.rb",
            "line_number" => 10,
            "run_time" => 0.5,
            "pending_message" => nil,
          },
          {
            "id" => "./spec/example_spec.rb[1:4]",
            "description" => "is pending",
            "full_description" => "RSpec Summary Generator is pending",
            "status" => "pending",
            "file_path" => "./spec/example_spec.rb",
            "line_number" => 20,
            "run_time" => 0.3,
            "pending_message" => "Not implemented yet",
          },
        ],
      }.to_json
    end

    it "does not include the failures section" do
      summary = File.read(summary_file.path)
      expect(summary).not_to include("#### Failures:")
    end

    it "does not output anything" do
      output = File.read(output_file.path)
      expect(output).to eq "failing_tests<<EOF\n\nEOF\n"
    end
  end

  context "when there are no pending examples" do
    let(:json_content) do
      {
        "seed" => 12345,
        "examples" => [
          {
            "id" => "./spec/example_spec.rb[1:1]",
            "description" => "passes correctly",
            "full_description" => "RSpec Summary Generator passes correctly",
            "status" => "passed",
            "file_path" => "./spec/example_spec.rb",
            "line_number" => 10,
            "run_time" => 0.5,
            "pending_message" => nil,
          },
          {
            "id" => "./spec/example_spec.rb[1:2]",
            "description" => "fails intentionally",
            "full_description" => "RSpec Summary Generator fails intentionally",
            "status" => "failed",
            "file_path" => "./spec/example_spec.rb",
            "line_number" => 15,
            "run_time" => 70.4,
            "pending_message" => nil,
            "exception" => {
              "class" => "RSpec::Expectations::ExpectationNotMetError",
              "message" => "expected: 2\n     got: 1",
            },
          },
        ],
      }.to_json
    end

    it "does not include the pending section" do
      summary = File.read(summary_file.path)
      expect(summary).not_to include("#### Pending:")
    end
  end

  describe "#format_duration" do
    it "rounds seconds down" do
      expect(format_duration(0.9)).to eq("0s")
    end

    it "formats seconds correctly" do
      expect(format_duration(45)).to eq("45s")
    end

    it "formats minutes and seconds correctly" do
      expect(format_duration(125)).to eq("2m5s")
    end

    it "formats hours, minutes, and seconds correctly" do
      expect(format_duration(3665)).to eq("1h1m5s")
    end

    it "does not include minutes if only seconds exist" do
      expect(format_duration(59)).to eq("59s")
    end

    it "does not include seconds if exactly an hour" do
      expect(format_duration(3600)).to eq("1h")
    end

    it "includes minutes but not seconds when even minute count" do
      expect(format_duration(1800)).to eq("30m")
    end
  end

  xit "has a pending test"

  if ENV["FAIL"]
    it "has a failing test" do
      expect(1).to eq(2)
    end
  end
end
