document.addEventListener('DOMContentLoaded', function() {
  console.log('SlackTranslator UI inicializada');
  
  const englishCol = document.getElementById('english-messages');
  const portugueseCol = document.getElementById('portuguese-messages');
  
  let processedMessages = [];
  
  function renderMessage(message) {
    const messageId = `${message.original}-${message.timestamp}`;
    if (processedMessages.includes(messageId)) {
      return;
    }
    
    processedMessages.push(messageId);
    
    const timestamp = message.timestamp 
      ? `<small>${new Date(message.timestamp * 1000).toLocaleTimeString()}</small><br>` 
      : '';
    
    const englishDiv = document.createElement('div');
    englishDiv.className = 'message';
    englishDiv.innerHTML = timestamp + message.original;
    englishCol.appendChild(englishDiv);
    
    const portugueseDiv = document.createElement('div');
    portugueseDiv.className = 'message';
    portugueseDiv.innerHTML = timestamp + message.translation;
    portugueseCol.appendChild(portugueseDiv);
    
    englishCol.scrollTop = englishCol.scrollHeight;
    portugueseCol.scrollTop = portugueseCol.scrollHeight;
    
    console.log('Mensagem renderizada:', message.original);
  }
  
  function fetchMessages() {
    fetch('/messages')
      .then(response => {
        if (!response.ok) {
          throw new Error(`Status: ${response.status}`);
        }
        return response.json();
      })
      .then(messages => {
        console.log('Mensagens recebidas:', messages.length);
        
        messages.forEach(message => renderMessage(message));
      })
      .catch(error => {
        console.error('Erro ao buscar mensagens:', error);
      });
  }
  
  fetchMessages();
  
  setInterval(fetchMessages, 3000);
  
  const testButton = document.getElementById('test-button');
  if (testButton) {
    testButton.addEventListener('click', function(event) {
      console.log('Botão de teste clicado');
      event.preventDefault();
      
      fetch('/test-message')
        .then(response => response.json())
        .then(data => {
          console.log('Mensagem de teste enviada:', data);
          fetchMessages();
        })
        .catch(error => console.error('Erro ao enviar mensagem de teste:', error));
    });
  }
  
  const replyForm = document.getElementById('reply-form');
  if (replyForm) {
    replyForm.addEventListener('submit', function(e) {
      e.preventDefault();
    });
  }
});
