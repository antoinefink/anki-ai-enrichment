# Anki and CSV AI Enrichment using GPT or Perplexity

This script enriches CSV columns using **Perplexity** or **OpenAI's GPT**. You can either update an existing column or add a new one. It is especially useful for quickly adding data to a file or programmatically fixing existing data.

I've used it to enrich and improve decks for Anki.

## Requirements

- **Ruby** 3.x or higher
- Valid **API keys** for Perplexity or GPT (configure in the script)

## Installation

Copy the `.env.example` file to `.env` and add your API keys:

```bash
cp .env.example .env
```

Then edit `.env` to add your API keys.

## Usage

The script requires input and output files to be specified using command-line options:

```bash
ruby script.rb -i input.csv -o output.csv [command] [args]
```

Available options:
- `-i, --input FILE`: Input CSV file (required)
- `-o, --output FILE`: Output CSV file (required)
- `-s, --separator SEP`: CSV separator (default: tab)
- `--headers`: CSV has headers
- `--skip-lines N`: Skip N initial lines

Commands:

1. List columns:
```bash
ruby script.rb -i input.csv -o output.csv columns
```

2. Enrich a column with Perplexity:
```bash
ruby script.rb -i input.csv -o output.csv perplexity <COLUMN_INDEX> "Your prompt"
```

3. Enrich a column with GPT:
```bash
ruby script.rb -i input.csv -o output.csv gpt <COLUMN_INDEX> "Convert the plain text to HTML markup: {column_1}"
```

A few notes:
- You can reference other columns in your prompt using `{column_#}`. For example, for column 1, you can use `{column_1}`.
- Perplexity won't erase existing content.
- You can customize the system prompts for GPT and Perplexity in the `.env` file.
