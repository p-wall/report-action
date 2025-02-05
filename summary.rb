#!/usr/bin/env ruby

require "json"

pattern = ENV["PATTERN"] || "*.json"
  # const baseUrl = `${github.context.serverUrl}/${github.context.repo.owner}/${github.context.repo.repo}/blob/${github.context.sha}`
base_url = ENV["GITHUB_SERVER_URL"] + "/" + ENV["GITHUB_REPOSITORY"] + "/blob/" + ENV["GITHUB_SHA"]

summary = "### RSpec Summary\n\n"
matching_files = Dir.glob(pattern)

total_examples = 0
total_failures = 0
total_pending = 0
max_runtime_overall = 0

failed_examples = []
pending_examples = []

def format_duration(seconds)
  hours = (seconds / 3600).to_i
  minutes = ((seconds % 3600) / 60).to_i
  seconds = (seconds % 60).to_i

  formatted_time = []
  formatted_time << "#{hours}h" if hours > 0
  formatted_time << "#{minutes}m" if minutes > 0
  formatted_time << "#{seconds}s" if formatted_time.empty? || seconds > 0
  formatted_time.join
end

matching_files.each do |file|
  json = JSON.parse(File.read(file))
  max_runtime = json["examples"].sum { |example| example["run_time"] } || 0
  max_runtime_overall = [ max_runtime_overall, max_runtime ].max

  total_examples += json["examples"].size

  json["examples"].each do |example|
    if example["status"] == "failed"
      total_failures += 1
      failed_examples << [ example, json["seed"] ]
    elsif example["status"] == "pending"
      total_pending += 1
      pending_examples << example
    end
  end
end

summary += "#{total_examples} examples, #{total_failures} failures, #{total_pending} pending in #{format_duration(max_runtime_overall)}\n\n"

all_same_seed = failed_examples.map(&:last).uniq.size == 1

if total_failures > 0
  summary += "#### Failures:\n"
  summary += "| Example | Description | Message |\n"
  summary += "| --- | --- | --- |\n"
  failed_examples.each do |example, seed|
    example_link_text = "#{example["file_path"]}:#{example["line_number"]}".delete_prefix("./")
    exmaple_link_url = "#{base_url}/#{example["file_path"].delete_prefix("./")}#L#{example["line_number"]}"
    example_link = "[<code>#{example_link_text}</code>](#{exmaple_link_url})"
    exception_class = example.dig("exception", "class") || "UnknownError"
    message = example.dig("exception", "message") || ""
    message = message
      .gsub("\n", "<br />")
      .gsub(/\e\[[0-9;]*m/, "") # Strip ANSI codes

    example_link += " --seed #{seed})" unless all_same_seed
    summary += "| #{example_link} | #{example["full_description"]} | <pre>#{exception_class}<br />#{message}</pre> |\n"
  end
end

if total_pending > 0
  summary += "\n#### Pending:\n"
  summary += "| Example | Description | Message |\n"
  summary += "| --- | --- | --- |\n"
  pending_examples.each do |example|
    example_link_text = "#{example["file_path"]}:#{example["line_number"]}".delete_prefix("./")
    exmaple_link_url = "#{base_url}/#{example["file_path"].delete_prefix("./")}#L#{example["line_number"]}"
    example_link = "[<code>#{example_link_text}</code>](#{exmaple_link_url})"
    message = example["pending_message"] || ""
    summary += "| #{example_link} | #{example["full_description"]} | <pre>#{message}</pre> |\n"
  end
end

if all_same_seed
  summary += "\nAll examples run with <code>--seed #{failed_examples.first[1]}</code>\n"
end

File.write(ENV["GITHUB_STEP_SUMMARY"], summary, mode: "a+")


failing_tests = failed_examples.map { |example, _seed|
  file = "#{example["file_path"]}:#{example["line_number"]}".delete_prefix("./")
  klass = example.dig("exception", "class") || "UnknownError"
  message = example.dig("exception", "message") || ""
  message = message.gsub("\n", " ").gsub(/\e\[[0-9;]*m/, "")
  "#{file} - #{klass}: #{message}"
}

File.open(ENV["GITHUB_OUTPUT"], "a+") { |file|
  file.write "failing_tests<<EOF\n"
  file.write failing_tests.join("\n")
  file.write "\nEOF\n"
}
