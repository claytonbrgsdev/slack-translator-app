require 'slack-ruby-client'
require 'logger'
require 'json'
require 'net/http'
require_relative 'ollama_client'

module SlackClient
  class << self
    attr_accessor :web_client, :logger, :last_timestamp
  end
  
  def self.connect!
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
    @logger.info "Inicializando cliente Slack..."
    
    unless ENV['SLACK_API_TOKEN'] && ENV['SLACK_CHANNEL_ID']
      @logger.error "Erro: SLACK_API_TOKEN e SLACK_CHANNEL_ID devem estar configurados"
      return
    end
    
    Slack.configure do |config|
      config.token = ENV['SLACK_API_TOKEN']
    end

    @web_client = Slack::Web::Client.new
    
    @logger.info "Configurando monitoramento para canal #{ENV['SLACK_CHANNEL_ID']}"
    
    begin
      auth_test = @web_client.auth_test
      @logger.info "Conectado ao Slack como: #{auth_test.user} (#{auth_test.team})"
      
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
  
  def self.monitor_channel
    processed_messages = {}
    
    loop do
      begin
        channel_id = ENV['SLACK_CHANNEL_ID']
        oldest = @last_timestamp.to_s
        
        @logger.info "Buscando mensagens (desde #{Time.at(@last_timestamp)})..."
        
        response = @web_client.conversations_history(
          channel: channel_id,
          oldest: oldest,
          limit: 10,
          inclusive: false
        )
        
        if response && response.messages && !response.messages.empty?
          @logger.info "Encontradas #{response.messages.size} mensagens novas"
          
          response.messages.reverse.each do |msg|
            next if processed_messages[msg.ts] || msg.subtype == 'bot_message'
            processed_messages[msg.ts] = true
            
            msg_time = msg.ts.to_f
            @last_timestamp = msg_time if msg_time > @last_timestamp
            
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
      
      sleep 3
    end
  end
  
  def self.get_user_info(user_id)
    begin
      @web_client.users_info(user: user_id).user
    rescue => e
      @logger.error "Erro ao obter informações do usuário #{user_id}: #{e.message}"
      nil
    end
  end

  def self.process_message(ts, text)
    original = text
    @logger.info "Processando mensagem: #{original[0..30]}..."
    
    begin
      @logger.info "Traduzindo mensagem via Ollama..."
      translation = OllamaClient.translate_en_to_pt(original)
      @logger.info "Tradução concluída: #{translation[0..30]}..."
    rescue => e
      @logger.error "Erro na tradução: #{e.message}"
      translation = "[Erro na tradução] #{original}"
    end
    
    begin
      message = { original: original, translation: translation, timestamp: Time.now.to_i }
      send_to_webapp(message)
    rescue => e
      @logger.error "Erro ao processar mensagem: #{e.message}"
    end
  end
  
  def self.send_to_webapp(message)
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
  
  def self.test_message(text="Hello, this is a test message from Slack.", username="Test User")
    ts = Time.now.to_f.to_s
    message_text = "#{username}: #{text}"
    process_message(ts, message_text)
  end
end
