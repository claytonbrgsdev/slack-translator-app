# State Management Documentation

## Overview

This document covers the state management strategy for the SlackTranslator application. The application primarily uses in-memory storage to manage real-time data and temporary user-specific state. Future enhancements may integrate persistent storage.

## Session Management

- **User-Specific Data:**  
  The application uses a custom session management approach (via in-memory storage) to handle:
  - Pending message translations and confirmations.
  - Temporary user settings or data during a session.
  
- **Implementation Details:**
  - Sessions are managed using Ruby's standard libraries rather than framework-specific session mechanisms.
  - A unique in-memory session (e.g., via cookies and hashes) is maintained for each user.

## Global State Management

- **Real-Time Message Handling:**
  - An in-memory store (such as a Ruby hash or array) is used to:
    - Capture live Slack messages.
    - Track translation statuses (e.g., received, translated, awaiting confirmation).
  - The SSE endpoint pulls data from this store to push real-time updates to clients.
  
- **Concurrency Considerations:**
  - For this proof-of-concept, a simple Ruby data structure is used.
  - Future versions might employ thread-safe structures or external datastores for improved concurrency.

## Persistence Considerations

- **Current Strategy:**  
  - Data is managed in memory for rapid development and testing.
- **Future Enhancements:**  
  - Integrate a lightweight database (e.g., SQLite or PostgreSQL) or adopt file-based logging to persist data.

## Summary

- **Sessions:**
Utilized for user-specific, temporary data such as pending translations.
- **Global Store:**
Used for real-time tracking of Slack messages and translation statuses.
- **Future Enhancements:**
Persistence via a lightweight database or file-based logging can be integrated once the core real-time functionality is proven.
