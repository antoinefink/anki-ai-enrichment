# CSV AI Enrichment using GPT or Perplexity

This script enriches CSV columns using **Perplexity** or **OpenAI's GPT**. You can either update an existing column or add a new one. It is especially useful for quickly adding data to a file or programmatically fixing existing data.

I've used it to enrich and improve decks for Anki.

## Requirements

- **Ruby** 3.x or higher
- Valid **API keys** for Perplexity or GPT (configure in the script)

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
ruby script.rb gpt <COLUMN_INDEX> "Convert the plain text to HTML markup: {column_1}"
```

A few notes:
- You can reference other columns in your prompt using `{column_#}`. For example, for column 1, you can use `{column_1}`.
- Perplexity won't erase existing content.
- I personally prefer to change the system prompt for GPT. You can do that in the `.env` file.
