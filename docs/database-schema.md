# Database Schema Documentation

## Overview
This document outlines a proposed database schema for future persistence needs. While the current version uses in-memory storage, the schema below is designed to store message logs, translation histories, and user interactions for a production-ready version.

## Proposed Schema

### 1. `messages` Table

- **Purpose:**  
  - Store information about incoming Slack messages and their translation statuses.
- **Columns:**
  - `id` (Primary Key): Unique identifier.
  - `slack_message_id`: Identifier of the original Slack message.
  - `original_text`: Message content in English.
  - `translated_text`: Translated content in Portuguese.
  - `status`: Message status (e.g., "received", "translated", "confirmed").
  - `created_at`: Timestamp of message receipt.
  - `updated_at`: Timestamp of the last update.

### 2. `replies` Table

- **Purpose:**  
  - Record user replies and track the translation process for responses.
- **Columns:**
  - `id` (Primary Key): Unique identifier.
  - `message_id` (Foreign Key): Reference to the associated message.
  - `reply_original`: Reply text in Portuguese.
  - `reply_translated`: Reply text in English after translation.
  - `status`: Reply status (e.g., "pending", "confirmed", "posted").
  - `created_at`: Timestamp when the reply was submitted.
  - `updated_at`: Timestamp of the last update.

### 3. `logs` Table

- **Purpose:**  
  - Store log records for debugging, performance monitoring, and auditing.
- **Columns:**
  - `id` (Primary Key): Unique identifier.
  - `level`: Log level (INFO, ERROR, DEBUG).
  - `message`: Log details.
  - `timestamp`: When the log entry was created.

## Relationships

- **Messages to Replies:**  
  - One-to-many relationship: each message may have several associated replies via the `message_id` foreign key in the `replies` table.

## Indexing and Migrations

- **Indexing:**  
  - Index `slack_message_id` in the `messages` table to speed up lookups.
  - Index `message_id` in the `replies` table to optimize join queries.
- **Migration Tools:**  
  - Utilize Ruby migration tools (such as Sequel or ActiveRecord Migrations) to handle schema updates and version control.

## Future Considerations

- **Data Archiving:**  
  - Implement archiving strategies for outdated data while maintaining system performance.
- **Scalability:**  
  - Optimize the schema further based on real usage patterns and growth.
