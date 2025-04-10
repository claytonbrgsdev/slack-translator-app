# User Flow Documentation

## Overview
This document defines the core user journey for the SlackTranslator application, outlining each step from message capture to translation, user interaction, and final message posting.

## Core User Journey

1. **Message Reception:**
   - A message is posted in English on Slack.
   - The backend captures the message in real time via the Slack RTM API.

2. **Translation & Display:**
   - The captured message is sent to the Ollama API for translation into Portuguese.
   - The English message is displayed in the left column of the web interface.
   - The translated Portuguese message appears in the right column.

3. **User Interaction:**
   - The user reviews the translated message.
   - The user types a reply in Portuguese in an input field located in the Portuguese column.

4. **Reply Processing:**
   - The reply is submitted to the backend.
   - The backend translates the reply from Portuguese back to English.
   - A confirmation page is displayed, showing the translated English reply for user approval.

5. **Final Posting:**
   - Upon confirmation, the final English reply is posted back to the original Slack channel.

## Mermaid Diagram

```mermaid
flowchart TD
    A[Slack Message Posted (English)]
    B[Backend Captures Message]
    C[Send Message to Ollama for Translation]
    D[Receive Translated Message (Portuguese)]
    E[Display Messages: English (Left) | Portuguese (Right)]
    F[User Types Reply in Portuguese]
    G[Submit Reply to Backend]
    H[Translate Reply to English]
    I[Display Confirmation Page with English Reply]
    J[User Confirms Reply]
    K[Post English Reply to Slack]

    A --> B
    B --> C
    C --> D
    D --> E
    E --> F
    F --> G
    G --> H
    H --> I
    I --> J
    J --> K
```

## Additional Considerations

- **Error Handling:**
  At any step (e.g., translation failure or network issues), error handling mechanisms will notify the user and log the issue.
- **Real-Time Updates:**
  The web interface uses Server-Sent Events (SSE) to update the conversation flow in real time as new messages or status changes occur.
