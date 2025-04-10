# API Communication Documentation

## Overview
This document outlines the API endpoints and communication strategies for the Slack real-time multilingual communication application. The API is built using a custom pure Ruby HTTP server (WEBrick) and adheres to RESTful principles where applicable. Real-time updates are delivered via Server-Sent Events (SSE) to maintain an up-to-date user interface.

## Endpoints

### GET /
- **Purpose:**  
  Renders the main HTML page featuring a two-column layout: English messages in the left column and Portuguese messages (along with a reply input field) in the right column.
- **Method:** GET
- **URL:** `/`
- **Response:**  
  A complete HTML page generated from ERB templates.
- **Notes:**  
  This is the primary entry point for users accessing the web interface.

### GET /sse
- **Purpose:**  
  Provides a continuous stream of Server-Sent Events (SSE) for real-time updates including new messages, translation status changes, and notification events.
- **Method:** GET
- **URL:** `/sse`
- **Response:**  
  An SSE stream where each event is a JSON object containing details such as:
  ```json
  {
    "type": "new_message",
    "message_id": "12345",
    "original_text": "Hello world!",
    "translated_text": "Olá mundo!"
  }
  •	Notes:
The SSE endpoint is implemented via a custom pure Ruby server using WEBrick.

### POST /reply
- **Purpose:**  
  Handles submission of replies. This endpoint receives the user's reply in Portuguese, translates it to English via the translation service, and returns a confirmation view. Once confirmed, the final English message is posted to Slack.
- **Method:** POST
- **URL:** `/reply`
- **Request Payload:**
  - **Type:** Form-data or JSON (depending on implementation)
  - **Contents:**
    - `reply_text`: The reply composed in Portuguese.
    - `original_message_id`: (Optional) Identifier of the message being replied to.
- **Response:**  
  A confirmation page displaying the translated text and awaiting user confirmation before the reply is posted to Slack.
- **Error Handling:**
  - Validates that the reply text is not empty.
  - Manages translation errors or failures in posting the reply back to Slack.
  - Returns appropriate HTTP status codes (e.g., 400 for bad requests, 500 for server errors).