# CSV AI Enrichment using GPT or Perplexity

This script enriches CSV columns using **Perplexity** or **GPT**. You can either update an existing column or add a new one. It is especially useful for quickly adding data to a file or programmatically fixing existing data.

## Requirements

- **Ruby** 3.x or higher
- Valid **API keys** for Perplexity and GPT (configure in the script)

## Installation

Modify the `.env.example` file with your API keys and configuration. Then run `mv .env.example .env` to have it be loaded.

## Usage

1. List columns:

```
ruby script.rb columns
```

2. Enrich a column with Perplexity:

```
ruby script.rb perplexity <COLUMN_INDEX> "Your prompt"
```

3. Enrich a column with GPT:

```
ruby script.rb gpt <COLUMN_INDEX> "Your prompt"
```

Columns are zero-based, and only empty cells get filled. Results are saved to output.csv by default.