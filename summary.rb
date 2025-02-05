#!/usr/bin/env ruby

require "json"

pattern = ENV["PATTERN"] || "*.json"
base_url = ENV["GITHUB_SERVER_URL"] + "/" + ENV["GITHUB_REPOSITORY"]
blob_url = base_url + "/blob/" + ENV["GITHUB_SHA"]
commit_url = base_url + "/commit/" + ENV["GITHUB_SHA"]
run_url = base_url + "/actions/runs/" + ENV["GITHUB_RUN_ID"]

summary = "### RSpec Summary\n\n"
matching_files = Dir.glob(pattern)

total_examples = 0
total_failures = 0
total_pending = 0
max_runtime_overall = 0

failed_examples = []
pending_examples = []
broken_files = []

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
  content = File.read(file)
  if content.strip.empty?
    broken_files << file
    next
  end

  json = JSON.parse(content)
  unless json.key?("examples")
    broken_files << file
    next
  end

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
rescue JSON::ParserError, StandardError
  broken_files << file
end

summary += "#{total_examples} examples, #{total_failures} failures, #{total_pending} pending in #{format_duration(max_runtime_overall)}\n\n"

if broken_files.any?
  summary += "#### Broken Files:\n"
  broken_files.each do |file|
    summary += "- #{file}\n"
  end
end

all_same_seed = failed_examples.map(&:last).uniq.size == 1

if total_failures > 0
  summary += "#### Failures:\n"
  summary += "| Example | Description | Message |\n"
  summary += "| --- | --- | --- |\n"
  failed_examples.each do |example, seed|
    example_link_text = "#{example["file_path"]}:#{example["line_number"]}".delete_prefix("./")
    example_link_url = "#{blob_url}/#{example["file_path"].delete_prefix("./")}#L#{example["line_number"]}"
    example_link = "[<code>#{example_link_text}</code>](#{example_link_url})"
    exception_class = example.dig("exception", "class") || "UnknownError"
    message = example.dig("exception", "message") || ""
    message = message.gsub("\n", "<br />").gsub(/\e\[[0-9;]*m/, "") # Strip ANSI codes

    example_link += " --seed #{seed}" unless all_same_seed
    summary += "| #{example_link} | #{example["full_description"]} | <pre>#{exception_class}<br />#{message}</pre> |\n"
  end
end

if total_pending > 0
  summary += "\n#### Pending:\n"
  summary += "| Example | Description | Message |\n"
  summary += "| --- | --- | --- |\n"
  pending_examples.each do |example|
    example_link_text = "#{example["file_path"]}:#{example["line_number"]}".delete_prefix("./")
    example_link_url = "#{blob_url}/#{example["file_path"].delete_prefix("./")}#L#{example["line_number"]}"
    example_link = "[<code>#{example_link_text}</code>](#{example_link_url})"
    message = example["pending_message"] || ""
    summary += "| #{example_link} | #{example["full_description"]} | <pre>#{message}</pre> |\n"
  end
end

if all_same_seed && total_failures > 0
  summary += "\nAll examples run with <code>--seed #{failed_examples.first[1]}</code>\n"
end

File.write(ENV["GITHUB_STEP_SUMMARY"], summary, mode: "a+")

if total_failures > 0 || broken_files.any?
  slack_message = "<#{run_url}|GitHub Actions> saw test failures for <#{commit_url}|#{ENV["GITHUB_SHA"][0..6]}> by #{ENV["GITHUB_ACTOR"]}:\n"
  slack_message += "*RSpec Failures (#{total_failures} total):*\n"
  broken_files.each { |file| slack_message += "• Broken file: #{file}\n" }

  failed_examples.first(5).each do |example, seed|
    file_path = example["file_path"].delete_prefix("./")
    line_number = example["line_number"]
    example_url = "#{blob_url}/#{file_path}#L#{line_number}"
    exception_class = example.dig("exception", "class") || "UnknownError"
    message = example.dig("exception", "message") || ""
    message = message.gsub(/\e\[[0-9;]*m/, "").gsub("`", "").strip

    slack_message += "• <#{example_url}|#{file_path}:#{line_number}>"
    slack_message += " --seed #{seed}" unless all_same_seed
    slack_message += "\n```#{exception_class}\n#{message}```\n"
  end

  File.open(ENV["GITHUB_OUTPUT"], "a+") do |file|
    file.puts "slack_message<<EOF"
    file.puts slack_message
    file.puts "EOF"
  end
end
