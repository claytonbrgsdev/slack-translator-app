# lib/slack_client.rb
require 'slack-ruby-client'
require 'logger'
require 'json'
require 'net/http'
require_relative 'ollama_client'

module SlackClient
  class << self
    attr_accessor :web_client, :logger, :last_timestamp
  end
  
  # Configura e inicia o cliente Slack
  def self.connect!
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
    @logger.info "Inicializando cliente Slack..."
    
    unless ENV['SLACK_API_TOKEN'] && ENV['SLACK_CHANNEL_ID']
      @logger.error "Erro: SLACK_API_TOKEN e SLACK_CHANNEL_ID devem estar configurados"
      return
    end
    
    # Configurar cliente Slack
    Slack.configure do |config|
      config.token = ENV['SLACK_API_TOKEN']
    end

    # Inicializar cliente Web API
    @web_client = Slack::Web::Client.new
    
    @logger.info "Configurando monitoramento para canal #{ENV['SLACK_CHANNEL_ID']}"
    
    # Testar conexão com o Slack
    begin
      auth_test = @web_client.auth_test
      @logger.info "Conectado ao Slack como: #{auth_test.user} (#{auth_test.team})"
      
      # Iniciar monitoramento em thread separada
      @last_timestamp = Time.now.to_i - 300 # Últimos 5 minutos
      Thread.new do
        monitor_channel
      end
      
      true
    rescue => e
      @logger.error "Erro ao conectar ao Slack: #{e.message}"
      false
    end
  end
  
  # Monitorar mensagens do canal usando conversations_history
  def self.monitor_channel
    # Hash para rastreamento de mensagens processadas
    processed_messages = {}
    
    loop do
      begin
        # Obter novas mensagens do canal
        channel_id = ENV['SLACK_CHANNEL_ID']
        oldest = @last_timestamp.to_s
        
        @logger.info "Buscando mensagens (desde #{Time.at(@last_timestamp)})..."
        
        # Chamar a API Slack
        response = @web_client.conversations_history(
          channel: channel_id,
          oldest: oldest,
          limit: 10,
          inclusive: false
        )
        
        if response && response.messages && !response.messages.empty?
          @logger.info "Encontradas #{response.messages.size} mensagens novas"
          
          # Processar mensagens mais antigas primeiro
          response.messages.reverse.each do |msg|
            # Pular mensagens já processadas ou de bot
            next if processed_messages[msg.ts] || msg.subtype == 'bot_message'
            processed_messages[msg.ts] = true
            
            # Atualizar timestamp mais recente para próxima consulta
            msg_time = msg.ts.to_f
            @last_timestamp = msg_time if msg_time > @last_timestamp
            
            # Processar a mensagem
            user_info = get_user_info(msg.user) if msg.user
            username = user_info ? user_info.real_name || user_info.name : "Usuário desconhecido"
            
            message_text = "#{username}: #{msg.text}"
            process_message(msg.ts, message_text)
          end
        else
          @logger.info "Nenhuma mensagem nova encontrada"
        end
      rescue => e
        @logger.error "Erro ao monitorar mensagens: #{e.message}"
      end
      
      # Intervalo de polling (3 segundos)
      sleep 3
    end
  end
  
  # Obter informações do usuário da Slack API
  def self.get_user_info(user_id)
    begin
      @web_client.users_info(user: user_id).user
    rescue => e
      @logger.error "Erro ao obter informações do usuário #{user_id}: #{e.message}"
      nil
    end
  end

  # Processar mensagem e enviar para o aplicativo web
  def self.process_message(ts, text)
    # Obter o texto original
    original = text
    @logger.info "Processando mensagem: #{original[0..30]}..."
    
    # Traduzir usando Ollama
    begin
      @logger.info "Traduzindo mensagem via Ollama..."
      translation = OllamaClient.translate_en_to_pt(original)
      @logger.info "Tradução concluída: #{translation[0..30]}..."
    rescue => e
      @logger.error "Erro na tradução: #{e.message}"
      translation = "[Erro na tradução] #{original}"
    end
    
    # Enviar mensagem para o endpoint do aplicativo web via HTTP
    begin
      message = { original: original, translation: translation, timestamp: Time.now.to_i }
      send_to_webapp(message)
    rescue => e
      @logger.error "Erro ao processar mensagem: #{e.message}"
    end
  end
  
  # Enviar mensagem para o aplicativo web local
  def self.send_to_webapp(message)
    # Inicializar logger se não existir
    @logger ||= Logger.new(STDOUT)
    
    begin
      uri = URI('http://localhost:3000/add-message')
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
      request.body = message.to_json
      response = http.request(request)
      
      @logger.info "Mensagem enviada para webapp: #{response.code}"
      return response.code.to_i == 200
    rescue => e
      @logger.error "Erro ao enviar mensagem para webapp: #{e.message}"
      return false
    end
  end
  
  # Para testes - simula uma mensagem recebida
  def self.test_message(text="Hello, this is a test message from Slack.")
    ts = Time.now.to_f.to_s
    process_message(ts, "[TEST] #{text}")
  end
end
