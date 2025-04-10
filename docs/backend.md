# Backend Documentation

## Overview
This document describes the backend architecture for the Slack real-time multilingual communication application. The backend is built in pure Ruby without Rails or Sinatra, using lightweight libraries and tools to capture Slack messages, perform translations via a local Ollama instance, and process confirmed replies. It also serves the web interface and provides a Server-Sent Events (SSE) endpoint for real-time updates using a custom HTTP server built with Ruby's WEBrick library.

## Tech Stack & Frameworks

- **Language:**  
  Ruby (without Rails or Sinatra)

- **Server:**  
  - **Custom Pure Ruby Server with WEBrick:**  
    A custom lightweight HTTP server built using Ruby's built-in WEBrick library is used to serve HTTP endpoints for the web interface (including SSE) and handle server-side rendering.

- **HTTP Client Library:**  
  - **http (gem):**  
    Used for making HTTP requests to the local Ollama API endpoint.

- **Third-Party Integration:**  
  - **Slack RTM API:**  
    Captures real-time messages from a designated Slack channel using a WebSocket connection.
  - **Ollama API:**  
    Sends and receives translation requests to/from the locally hosted LLM.

- **Logging:**  
  Lightweight file-based logging is implemented using Ruby's standard Logger for debugging and tracking message flows.

## Architecture & Workflow

### 1. Slack Integration

- **Message Capture:**  
  The backend connects to Slack's RTM API to capture incoming messages in real time.
  
- **Message Flow:**  
  - Incoming messages in English are received.
  - Messages are forwarded to the translation component for conversion into Portuguese.

### 2. Translation Service

- **Ollama Integration:**  
  - The backend makes HTTP requests to the locally hosted Ollama API to send the original English text.
  - The chosen LLM processes the translation and returns the Portuguese version.
  
- **Reverse Translation:**  
  - When a reply is drafted by the user in Portuguese, the reply is sent to Ollama for translation back to English.
  - The translated reply is displayed for user confirmation before being posted to Slack.

### 3. Message Processing & Slack Re-Posting

- **User Confirmation:**  
  After a reply is translated back to English and confirmed by the user via the web interface, the backend posts the final message into the original Slack channel.

- **Error Handling:**  
  - Each step includes error handling strategies, such as logging and retrying in case of API call failures.

### 4. Web Interface & Real-Time Communication

- **Custom HTTP Endpoints:**  
  The backend serves HTML views (using ERB templates) through the custom WEBrick server. Key endpoints include:
  - **GET /** – Renders the main page with a two-column layout.
  - **GET /sse** – Provides an SSE stream for real-time updates.
  
- **SSE for Real-Time Updates:**  
  A minimal JavaScript snippet in the served HTML subscribes to the `/sse` endpoint to receive live updates.

### 5. Logging & Monitoring

- **Logging:**  
  Basic file-based logging is used to track:
  - Received Slack messages.
  - Translation requests and responses.
  - Posting outcomes and any errors encountered.

## Deployment & Execution Notes

- **Running the Application:**  
  - The entire backend logic (including Slack integration, translation handling, and web serving) is initiated from a Ruby script.
  - Ensure that the Slack RTM API is properly configured with the necessary authentication tokens.
  - The local Ollama service must be running and accessible via its designated API endpoint.
  
- **Testing & Performance:**  
  - For this job interview test, timings for each stage (from message capture to confirmation and posting) are logged for performance insights.
  
- **Future Extensions:**  
  - Although the current implementation employs ephemeral logging, future iterations could incorporate a persistent database for audit trails, message history tracking, and enhanced performance analytics.