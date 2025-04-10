# SlackTranslator

Real-time multilingual communication for Slack that automatically translates messages between English and Portuguese.

## Features

- Real-time Slack message translation
- Two-column interface showing original and translated messages
- Reply composition in native language with confirmation
- Server-Sent Events for live updates

## Requirements

- Ruby 3.0+
- Ollama running locally
- Slack API token

## Setup

1. Clone the repository
2. Run `bundle install`
3. Copy `.env.example` to `.env` and fill in your credentials
4. Start the server with `bundle exec rackup`

## Usage

1. Start the application
2. Connect to the web interface
3. Messages from the configured Slack channel will appear in real-time
4. Compose replies in Portuguese which will be translated back to English

## Development

Run tests with:
```
bundle exec rspec
