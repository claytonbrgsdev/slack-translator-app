# Frontend Documentation

## Overview
This document outlines the frontend architecture for the Slack real-time multilingual communication application. The interface displays Slack messages and their translations in a minimal yet functional design. The web pages are rendered on the server side using ERB templates, served by a custom pure Ruby server built with WEBrick.

## Tech Stack & Architecture

- **Server Implementation:**  
  - **Custom Pure Ruby Server (WEBrick):**  
    The web interface is served by a custom Ruby server rather than a web framework like Sinatra.
  
- **Template Engine:**  
  - **ERB:** Used for generating dynamic HTML content on the server side.
  
- **Styling:**  
  - Custom CSS is used to maintain a minimal yet elegant design.
  
- **Real-Time Updates:**  
  - **Server-Sent Events (SSE):**  
    A minimal JavaScript snippet subscribes to the `/sse` endpoint for live updates.
  
- **Layout:**
  - **Two-Column Design:**
    - **Left Column:** Displays the original English messages.
    - **Right Column:** Displays the translated Portuguese messages and includes an input for drafting replies.

- **Accessibility & Future Enhancements:**
  - The system is designed to be accessible with the possibility of integrating features like text-to-speech in later iterations.
  - The overall design is kept minimal, yet it can be extended with advanced accessibility options as needed.

## Workflow & Functionality

1. **Message Retrieval:**
   - Slack messages are captured in real time by the backend.
   
2. **Translation Process:**
   - English messages are sent to the local Ollama API for translation into Portuguese.
   - Replies in Portuguese are subsequently translated back to English.
   
3. **Real-Time Interface Updates:**
   - Live updates are pushed via SSE to keep the conversation view current.
   
4. **User Interaction:**
   - The two-column layout allows users to compare the original and translated messages side by side.
   - A reply text box in the Portuguese column enables users to submit responses.

## Minimal JavaScript for SSE

While the core application logic runs in pure Ruby with WEBrick, a small JavaScript snippet is used for handling SSE:

```javascript
// Example: Minimal JavaScript for Server-Sent Events
const evtSource = new EventSource('/sse');
evtSource.onmessage = function(event) {
    const messageData = JSON.parse(event.data);
    // Update the DOM with new messages
    // Example: append the new message to the corresponding column
    // (DOM manipulation code goes here)
};
```

Note: This JavaScript is strictly limited to real-time event handling, keeping all business logic on the Ruby side.

## Future Considerations

- **Enhanced Styling:**
While the current styling is minimal and elegant, further customization can be applied to match branding or user preferences.
- **Advanced Accessibility:**
Future iterations may include features such as text-to-speech to better serve users with different accessibility needs.
- **Robust Error Handling:**
Both the SSE connection and the user interface will be enhanced with robust error handling to manage disconnections or message processing failures.
