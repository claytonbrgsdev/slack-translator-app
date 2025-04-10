require 'dotenv/load'
require 'webrick'
require 'json'
require 'securerandom'
require 'http'

class SlackTranslator
  OLLAMA_API_URL = ENV['OLLAMA_API_URL'] || 'http://localhost:11434/api/generate'
  SLACK_WEBHOOK_URL = ENV['SLACK_WEBHOOK_URL']
  
  def initialize
    @sessions = {}
    @translations = {}
    @server = setup_server
    start_slack_listener
  end

  def start
    @server.start
  end

  private

  def start_slack_listener
    Thread.new do
      # Send just one test message
      sleep 5 # Give browser time to load
      simulate_incoming_message
      puts "[DEBUG] Sent test Slack message"
    end
  end

  def simulate_incoming_message(provided_session_id = nil)
    sleep 5
    session_id = provided_session_id || SecureRandom.uuid
    message = {
      text: 'Hello world! This is a test message from Slack.',
      channel: 'general',
      user: 'U12345678'
    }
    
    @translations[session_id] = {
      original: message[:text],
      channel: message[:channel],
      status: 'received'
    }
    
    # Start translation process
    translate_message(session_id, message[:text])
  end

  def translate_message(session_id, text)
    Thread.new do
      puts "[DEBUG] Starting translation for session #{session_id}"
      
      begin
        response = HTTP.post(OLLAMA_API_URL, json: {
          model: 'llama3.1:8b',
          prompt: "Translate this to Portuguese: #{text}",
          stream: false
        })
        
        if response.status.success?
          translation = JSON.parse(response.body.to_s)['response']
          puts "[DEBUG] Translation successful: #{translation}"
          @translations[session_id][:translated_text] = translation
          @translations[session_id][:status] = 'translated'
        else
          puts "[ERROR] Translation failed: #{response.status.code}"
        end
      rescue => e
        puts "[ERROR] Translation exception: #{e.message}"
      end
    end
  end

  # --- Configuração do servidor HTTP e rotas ---
  def setup_server
    server = WEBrick::HTTPServer.new(Port: 3000)
    server.mount '/js', WEBrick::HTTPServlet::FileHandler, './public/js'
    server.mount '/css', WEBrick::HTTPServlet::FileHandler, './public/css'

    require 'erb'
  
    # Página inicial (serve HTML)
    server.mount_proc '/' do |req, res|
      res.content_type = 'text/html'
      template = ERB.new(File.read('views/index.erb'))
  
      # Pega o session_id
      session_id = req.cookies.find { |c| c.name == 'session_id' }&.value || SecureRandom.uuid
      res.cookies << WEBrick::Cookie.new('session_id', session_id)
  
      # Prepara mensagens para exibir no template
      translations = @translations[session_id]
      messages = []
      if translations
        messages << { language: 'en', content: translations[:original] }
        if translations[:translated_text]
          messages << { language: 'pt', content: translations[:translated_text] }
        end
      end
  
      @messages = messages
      @last_message_id = session_id
  
      res.body = template.result_with_hash(messages: messages, last_message_id: session_id)
    end

    # Canal de eventos SSE para comunicação em tempo real
    server.mount_proc '/sse' do |req, res|
      res.status = 200
      res.content_type = 'text/event-stream'
      res['Cache-Control'] = 'no-cache'
      res['Connection'] = 'keep-alive'
      session_id = req.cookies.find { |c| c.name == 'session_id' }&.value || SecureRandom.uuid
      @sessions[session_id] ||= { last_event_id: nil }
  
      res.chunked = true
      reader, writer = IO.pipe
      res.body = reader
  
      Thread.new do
        loop do
          translation = @translations[session_id]
          if translation && translation[:status] != @sessions[session_id][:last_event_id]
            writer.puts "data: #{translation.to_json.force_encoding('UTF-8')}\n"
            writer.puts
            writer.flush
            @sessions[session_id][:last_event_id] = translation[:status]
          end
          sleep 1
        end
      end
    end

    # Endpoint para envio de resposta traduzida de volta ao Slack
    server.mount_proc '/reply' do |req, res|
      if req.request_method == 'POST'
        if req['Content-Type'] && req['Content-Type'].include?('application/json')
          data = JSON.parse(req.body)
        else
          data = WEBrick::HTTPUtils.parse_query(req.body)
        end

        session_id = req.cookies.find { |c| c.name == 'session_id' }&.value

        if session_id && @translations[session_id]
          # Update the session with the reply and simulate reply translation
          @translations[session_id][:reply] = data['reply']
          @translations[session_id][:translated_reply] = "Hello, this is a test translation of reply: #{data['reply']}"
          @translations[session_id][:status] = 'reply_translated'
          
          if SLACK_WEBHOOK_URL.to_s.strip.empty?
            puts "[DEBUG] Slack webhook URL not configured; skipping reply posting."
          else
            HTTP.post(SLACK_WEBHOOK_URL, json: {
              text: data['reply'],
              channel: @translations[session_id][:channel]
            })
          end
          res.status = 200
          res.body = { status: 'success' }.to_json
        else
          res.status = 400
          res.body = { error: 'Invalid session' }.to_json
        end
      else
        res.status = 405
        res.body = { error: 'Method not allowed' }.to_json
      end
    end

    # Endpoint auxiliar para enviar uma mensagem de teste
    server.mount_proc '/test-message' do |req, res|
      if req.request_method == 'POST'
        session_id = req.cookies.find { |c| c.name == 'session_id' }&.value
        puts "[DEBUG] Received test message request for session_id=#{session_id}"
        simulate_incoming_message(session_id)
        res.status = 200
        res.body = { status: 'test_message_sent' }.to_json
      else
        res.status = 405
        res.body = { error: 'Method not allowed' }.to_json
      end
    end

    server
  end
end

SlackTranslator.new.start