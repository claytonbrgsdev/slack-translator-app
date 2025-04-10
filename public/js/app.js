document.addEventListener('DOMContentLoaded', function() {
  // Connect to SSE endpoint
  const eventSource = new EventSource('/sse');
  
  eventSource.onmessage = function(event) {
    console.log("SSE event received:", event.data);
    try {
      const data = JSON.parse(event.data);
      
      let column, messageContent;
      if(data.status === 'received') {
        column = document.getElementById('english-messages');
        messageContent = data.original;
      } else if(data.status === 'translated') {
        column = document.getElementById('portuguese-messages');
        messageContent = data.translated_text;
      } else if (data.status === 'reply_translated') {
        const portugueseCol = document.getElementById('portuguese-messages');
        const englishCol = document.getElementById('english-messages');

        const replyDiv = document.createElement('div');
        replyDiv.className = 'message';
        replyDiv.innerHTML = data.reply;
        portugueseCol.appendChild(replyDiv);

        const translatedReplyDiv = document.createElement('div');
        translatedReplyDiv.className = 'message';
        translatedReplyDiv.innerHTML = data.translated_reply;
        englishCol.appendChild(translatedReplyDiv);
      } else {
        console.warn('Received unknown status in SSE data:', data);
        return;
      }
      
      // Create message element
      const messageDiv = document.createElement('div');
      messageDiv.className = 'message';
      
      // Format message with timestamp if available
      const timestamp = data.timestamp ? `<small>${new Date(data.timestamp).toLocaleTimeString()}</small><br>` : '';
      messageDiv.innerHTML = timestamp + messageContent;
      
      // Add to column
      column.appendChild(messageDiv);
      
      // Auto-scroll to bottom
      column.scrollTop = column.scrollHeight;
      
    } catch (error) {
      console.error('Error processing SSE message:', error);
    }
  };
  
  eventSource.onerror = function(error) {
    console.error('SSE Error:', error);
    // Implement reconnection logic if needed
  };
  
  // Form submission handling
  const replyForm = document.getElementById('reply-form');
  if (replyForm) {
    replyForm.addEventListener('submit', function(e) {
      // Could add client-side validation here
    });
  }

  document.getElementById('test-button').addEventListener('click', function(event) {
    console.log('Test button clicked');
    event.preventDefault();
    fetch('/test-message', {
      method: 'POST',
      credentials: 'same-origin'
    })
    .then(response => response.json())
    .then(data => console.log('Test message sent:', data))
    .catch(error => console.error('Error sending test message:', error));
  });
});
