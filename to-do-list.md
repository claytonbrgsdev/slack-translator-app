# SlackTranslator To-Do List

This list outlines the development tasks required to build the SlackTranslator application, based on the provided documentation.

## Phase 1: Project Setup & Core Backend

*   [x] **Project Initialization:**
    *   [x] Create basic Ruby project directory structure.
    *   [x] Initialize `Gemfile`.
*   [x] **Dependency Management:**
    *   [x] Add `sinatra` gem to `Gemfile`.  *(Now removed; using pure Ruby)*
    *   [x] Add `http` gem (or similar) for Ollama API calls to `Gemfile`.
    *   [x] Add a Slack RTM client gem (e.g., `slack-ruby-client`) to `Gemfile`.
    *   [x] Add a testing framework gem (e.g., `rspec` or `minitest`) to `Gemfile`.
    *   [x] Run `bundle install`.

## Phase 2: Core Functionality - Slack & Translation

*   [ ] **Slack RTM Integration:**
    *   [ ] Implement connection to Slack RTM API using the chosen client gem.
    *   [ ] Implement listener for incoming messages from the designated Slack channel.
    *   [ ] Add error handling for Slack connection issues.
*   [ ] **Ollama Translation Client:**
    *   [ ] Create a module/class to handle communication with the Ollama API.
    *   [ ] Implement function to translate text from English to Portuguese.
    *   [ ] Implement function to translate text from Portuguese to English.
    *   [ ] Add error handling for Ollama API requests (timeouts, errors).
*   [ ] **In-Memory Message Store:**
    *   [ ] Implement a simple in-memory store (e.g., Array or Hash) to hold received messages and their translation status.
    *   [ ] Define message structure (e.g., `{ id: '...', original_text: '...', translated_text: '...', status: '...' }`).
*   [ ] **Core Message Processing:**
    *   [ ] Integrate Slack listener with the Ollama client: When an English message is received, trigger EN->PT translation.
    *   [ ] Update the in-memory store with the original message and its translation once available.

## Phase 3: Web Interface & API (Pure Ruby Implementation)

*   [x] **Basic Pure Ruby Web App:**
    *   [x] Create main application file (`app.rb`) using pure Ruby with WEBrick.
    *   [x] Implement endpoints:
        *   [x] `GET /` – Render the main view.
        *   [x] `GET /sse` – Provide a basic Server-Sent Events endpoint.
        *   [x] `POST /reply` – Accept reply submissions.
*   [ ] **Main View:**
    *   [x] Create a `views/` directory.
    *   [ ] Create an ERB template `views/index.erb` that builds a two-column layout with placeholders for English messages and Portuguese replies.

## Phase 4: Frontend Implementation

*   [ ] **HTML Structure:**
    *   [ ] Populate `views/index.erb` with divs/elements for:
        *   Left column (displaying original English messages).
        *   [ ] Right column (displaying translated Portuguese messages).
        *   [ ] Reply form (textarea and submit button) within the right column.
*   [ ] **CSS Styling:**
    *   [ ] Create a basic CSS file (e.g., `public/css/style.css`).
    *   [ ] Link the CSS file in `views/index.erb`.
    *   [ ] Add CSS rules for the two-column layout and minimal styling as per `docs/frontend.md`.
*   [ ] **JavaScript for SSE:**
    *   [ ] Add a minimal JavaScript snippet to `views/index.erb` (or a separate `public/js/app.js` file).
    *   [ ] Implement JavaScript to connect to the `/sse` endpoint (`EventSource`).
    *   [ ] Implement JavaScript logic to parse incoming SSE events (JSON).
    *   [ ] Implement JavaScript DOM manipulation to dynamically add/update messages in the correct columns based on SSE data.

## Phase 5: Reply Functionality

*   [ ] **Reply Translation (POST /reply):**
    *   [ ] Enhance the `/reply` handler to process the submitted Portuguese reply.
    *   [ ] Integrate the Ollama client to translate from Portuguese to English.
*   [ ] **Additional Processing:**
    *   [ ] Store necessary session or state data for confirmation, if needed.
    *   [ ] Post the translated reply back to Slack upon user confirmation.

## Phase 6: Testing

*   [ ] **Testing Setup:**
    *   [ ] Configure and implement tests for the pure Ruby HTTP server endpoints.
    *   [ ] Set up any necessary helper methods for testing server responses.
*   [ ] **Integration Tests:**
    *   [ ] Write tests for each endpoint (`/`, `/sse`, `/reply`) to validate behavior.

## Phase 7: Documentation & Finalization

*   [ ] **Code Documentation:**
    *   [ ] Add inline comments for non-obvious code logic.
*   [ ] **README Update:**
    *   [ ] Update `README.md` with setup instructions (including how to run the WEBrick server).
*   [ ] **Final Checks:**
    *   [ ] Verify that environment variables (if any) are correctly used.
    *   [ ] Ensure logging or error reporting is implemented as needed.