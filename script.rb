# Load environment variables from .env file
def load_env_file
  return unless File.exist?(".env")

  File.readlines(".env").each do |line|
    line.strip!
    next if line.empty? || line.start_with?("#")

    key, value = line.split("=", 2)
    # Interpret common escape sequences in the value
    value = value.gsub('\t', "\t").gsub('\n', "\n") if value
    ENV[key] = value if key && value
  end
end

# Load .env file before other requires
load_env_file

require 'csv'
require 'net/http'
require 'uri'
require 'json'
require 'debug'

# ------------------------------------------------
# CONFIGURATION
# ------------------------------------------------
# Perplexity config
PERPLEXITY_API_KEY       = ENV["PERPLEXITY_API_KEY"]
PERPLEXITY_MODEL         = ENV.fetch("PERPLEXITY_MODEL", "llama-3.1-sonar-small-128k-online")
PERPLEXITY_SYSTEM_PROMPT = ENV.fetch("PERPLEXITY_SYSTEM_PROMPT", "Be precise and concise.")

# GPT config
GPT_API_KEY       = ENV["GPT_API_KEY"]
GPT_MODEL_NAME    = ENV.fetch("GPT_MODEL_NAME", "gpt-4o")
GPT_SYSTEM_PROMPT = ENV.fetch("GPT_SYSTEM_PROMPT", "You are a helpful assistant.")

# CSV / File config
CSV_SEPARATOR      = ENV.fetch("CSV_SEPARATOR")
INPUT_CSV_FILE     = ENV.fetch("INPUT_CSV_FILE")
OUTPUT_CSV_FILE    = ENV.fetch("OUTPUT_CSV_FILE")
CSV_HAS_HEADERS    = ENV.fetch("CSV_HAS_HEADERS", "false") == "true"
SKIP_INITIAL_LINES = ENV.fetch("SKIP_INITIAL_LINES", "0").to_i

if File.exist?(OUTPUT_CSV_FILE)
  warn "Error: Output file '#{OUTPUT_CSV_FILE}' already exists. Please remove it or specify a different output file."
  exit 1
end

# ------------------------------------------------
# USAGE EXPLANATION
# ------------------------------------------------
# 1) List all columns with their indices:
#      ruby script.rb columns
#
# 2) Use Perplexity on a specific column:
#      ruby script.rb perplexity COL_INDEX "PROMPT"
#
# 3) Use GPT on a specific column:
#      ruby script.rb gpt COL_INDEX "PROMPT"
#
# Notes:
#   - COLUMN_NUMBER is zero-based (0, 1, 2, etc.)
#   - If you specify a column number that doesn't exist, it will create
#     new columns up to that index.
#   - Already filled cells are skipped. If you re-run, it fills only previously empty cells.
#   - Failures log an error but do not stop the entire script.
#   - Adjust config at the top of the file as needed.

def read_csv_with_headers(file, separator)
  lines = File.readlines(file)[SKIP_INITIAL_LINES..]
  CSV.parse(lines.join, col_sep: separator, headers: CSV_HAS_HEADERS, return_headers: false)
rescue Errno::ENOENT
  warn "Input CSV file '#{file}' not found. Creating an empty table with no headers."
  CSV::Table.new([])
end

def write_csv_with_headers(table, input_file, output_file, separator)
  # Add back the lines that were ignored
  lines = File.readlines(input_file)[0..SKIP_INITIAL_LINES - 1]
  File.write(output_file, lines.join) if lines.any? && SKIP_INITIAL_LINES > 0

  CSV.open(output_file, "a", col_sep: CSV_SEPARATOR, write_headers: CSV_HAS_HEADERS) do |csv|
    table.each { |row| csv << row }
  end
end

def list_columns(table)
  if table.empty?
    puts "No columns found (table is empty)."
    return
  end

  if table.respond_to?(:headers)
    table.headers.each_with_index do |header, idx|
      puts "#{idx} - #{header}"
    end
  else
    table.first.each_with_index do |cell, idx|
      puts "#{idx} - #{cell}"
    end
  end
end

def fetch_answer_from_perplexity(user_prompt)
  # Raise error only if we actually need the Perplexity key
  raise "Missing PERPLEXITY_API_KEY" if PERPLEXITY_API_KEY.nil? || PERPLEXITY_API_KEY.strip.empty?

  uri = URI("https://api.perplexity.ai/chat/completions")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  request_body = {
    model: PERPLEXITY_MODEL,
    messages: [
      { role: "system", content: PERPLEXITY_SYSTEM_PROMPT },
      { role: "user",   content: user_prompt }
    ],
    max_tokens: 1_000
  }

  request = Net::HTTP::Post.new(uri)
  request["Authorization"] = "Bearer #{PERPLEXITY_API_KEY}"
  request["Content-Type"]  = "application/json"
  request.body = request_body.to_json

  response = http.request(request)

  unless response.is_a?(Net::HTTPSuccess)
    raise "Perplexity API call failed (HTTP #{response.code}): #{response.body}"
  end

  data = JSON.parse(response.body)
  choice = data.dig("choices", 0, "message", "content")
  choice = choice.gsub(/\[\d+\]/, '') # Removes [1], [2], etc.
  choice
end

def fetch_answer_from_gpt(user_prompt)
  # Raise error only if we actually need the GPT key
  raise "Missing GPT_API_KEY" if GPT_API_KEY.nil? || GPT_API_KEY.strip.empty?

  uri = URI("https://api.openai.com/v1/chat/completions")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  request_body = {
    model: GPT_MODEL_NAME,
    messages: [
      { role: "system", content: GPT_SYSTEM_PROMPT },
      { role: "user",   content: user_prompt }
    ]
  }

  request = Net::HTTP::Post.new(uri)
  request["Authorization"] = "Bearer #{GPT_API_KEY}"
  request["Content-Type"]  = "application/json"
  request.body = request_body.to_json

  response = http.request(request)

  unless response.is_a?(Net::HTTPSuccess)
    raise "GPT API call failed (HTTP #{response.code}): #{response.body}"
  end

  data = JSON.parse(response.body)
  choice = data.dig("choices", 0, "message", "content")
  choice || "[No valid GPT response]"
end

def substitute_columns_in_prompt(user_prompt, row)
  # Use a regex to find occurrences of column_X
  user_prompt.gsub(/\bcolumn_(\d+)\b/) do
    col_idx = Regexp.last_match(1).to_i
    row[col_idx] || ""
  end
end

def fill_column(table, col_index, user_prompt, service)
  table.each_with_index do |row, row_idx|
    puts "----------------------------------------"
    puts "Row #{row_idx}"
    puts "Column #{col_index} cell value: #{row[col_index]}"

    cell_value = row[col_index]
    # Only fill empty cells if we're using Perplexity
    if (cell_value.nil? || cell_value.strip.empty?) || service == :gpt
      begin
        # Substitute placeholders in the prompt with values from this row
        substituted_prompt = substitute_columns_in_prompt(user_prompt, row)

        new_value = case service
                    when :perplexity
                      fetch_answer_from_perplexity(substituted_prompt)
                    when :gpt
                      fetch_answer_from_gpt(substituted_prompt)
                    else
                      raise "Unknown service: #{service}"
                    end

        puts "#{service} response: #{new_value}"

        row[col_index] = new_value
      rescue => e
        warn "Row #{row_idx} (column '#{col_index}') failed: #{e.message}"
      end
    else
      puts "Skipping row #{row_idx} (column '#{col_index}') because it's not empty"
    end
  end
end

if ARGV.empty?
  warn "Usage:\n" \
       "  ruby #{__FILE__} columns\n" \
       "  ruby #{__FILE__} perplexity COL_INDEX \"PROMPT\"\n" \
       "  ruby #{__FILE__} gpt COL_INDEX \"PROMPT\"\n"
  exit 0
end

command = ARGV[0]

case command
when "columns"
  table = read_csv_with_headers(INPUT_CSV_FILE, CSV_SEPARATOR)
  list_columns(table)

when "perplexity", "gpt"
  if ARGV.size < 3
    warn "Usage: ruby #{__FILE__} #{command} COL_INDEX \"PROMPT\""
    exit 1
  end

  col_index  = ARGV[1].to_i
  user_prompt = ARGV[2]

  table = read_csv_with_headers(INPUT_CSV_FILE, CSV_SEPARATOR)
  fill_column(table, col_index, user_prompt, command.to_sym)
  write_csv_with_headers(table, INPUT_CSV_FILE, OUTPUT_CSV_FILE, CSV_SEPARATOR)

  puts "Finished processing. Updated CSV written to '#{OUTPUT_CSV_FILE}'."

else
  warn "Unknown command: #{command}"
  warn "Valid commands are: columns, perplexity, gpt"
  exit 1
end
