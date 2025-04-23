require 'dotenv/load'
require 'sinatra'
require 'json'
require 'logger'
require 'sequel'

begin
  require_relative 'lib/slack_client'
  require_relative 'lib/ollama_client'
  $slack_available = true
rescue LoadError => e
  puts "Aviso: Não foi possível carregar biblioteca: #{e.message}"
  $slack_available = false
end

DB = Sequel.connect(ENV['DATABASE_URL'] || "sqlite://db/messages.db")
DB.create_table? :messages do
  primary_key :id
  String :original, text: true
  String :translation, text: true
  Integer :timestamp
  String :username
  String :user_image
  String :user_id
  Boolean :sent_by_me, default: false
end

class Message < Sequel::Model(:messages)
end

set :port, 3000
set :bind, '0.0.0.0'
set :environment, :development
set :public_folder, File.expand_path('../public', __FILE__)
set :views, File.expand_path('../views', __FILE__)
set :logging, true

configure do
  $logger = Logger.new(STDOUT)
  $logger.level = Logger::INFO
  $logger.info "Inicializando SlackTranslator em modo polling"
  
  if $slack_available && ENV['SLACK_API_TOKEN']
    Thread.new do
      $logger.info "Iniciando Slack Client"
      SlackClient.connect!
    end
  end
end

get '/' do
  erb :index
end

get '/messages' do
  content_type :json
  messages = Message.order(:timestamp).all
  messages.map(&:values).to_json
end

get '/test-message' do
  $logger.info "Recebendo requisição para enviar mensagem de teste"
  
  if $slack_available
    # Usar o método test_message do SlackClient que agora obtém
    # informações reais do usuário via API do Slack
    message_text = "This is a test message! #{Time.now.strftime('%H:%M:%S')}"
    success = SlackClient.test_message(message_text)
    
    $logger.info "Mensagem de teste processada via SlackClient: #{success ? 'Sucesso' : 'Falha'}"
    
    # A mensagem já foi adicionada à lista pelo SlackClient.process_message
    content_type :json
    { status: success ? 'ok' : 'error', 
      message: 'Test message sent', 
      original: message_text, 
      translation: "Esta é uma mensagem de teste! #{Time.now.strftime('%H:%M:%S')}" # Apenas para compatibilidade com o frontend
    }.to_json
  else
    $logger.warn "Tentativa de enviar mensagem de teste, mas Slack Client não está disponível"
    
    # Fallback se o Slack não estiver disponível
    original = "This is a test message! #{Time.now.strftime('%H:%M:%S')}"
    translation = "Esta é uma mensagem de teste! #{Time.now.strftime('%H:%M:%S')}"
    
    Message.create(original: original, translation: translation, timestamp: Time.now.to_i, username: "Test User")
    
    content_type :json
    { status: 'ok', message: 'Test message sent (fallback)', original: original, translation: translation }.to_json
  end
end

get '/sse' do
  content_type 'text/event-stream'
  headers['Cache-Control'] = 'no-cache'
  headers['Connection'] = 'keep-alive'
  
  "data: {\"connection\": \"established\"}\n\n"
end

get '/status' do
  content_type :json
  {
    app: "SlackTranslator",
    status: "running",
    env: settings.environment,
    channel_id: ENV['SLACK_CHANNEL_ID'] || "não configurado",
    api_token: ENV['SLACK_API_TOKEN'] ? "configurado" : "ausente",
    app_token: ENV['SLACK_APP_TOKEN'] ? "configurado" : "ausente",
    message_count: Message.count,
    slack_available: $slack_available
  }.to_json
end

# Novo endpoint para obter informações do usuário autenticado
get '/current-user-info' do
  content_type :json
  
  if $slack_available
    current_user_id = SlackClient.get_current_user_id
    $logger.info "Fornecendo ID do usuário atual via API: #{current_user_id || 'não disponível'}"
    
    if current_user_id
      # Obter informações detalhadas do usuário se tivermos o ID
      user_info = SlackClient.get_user_info(current_user_id)
      
      if user_info
        username = user_info.real_name || 
                 (user_info.profile&.display_name if user_info.profile&.display_name&.strip.to_s != '') || 
                 user_info.name
        
        # Buscar a imagem do perfil
        user_image = nil
        if user_info.profile
          user_image = user_info.profile.image_512 || 
                     user_info.profile.image_192 || 
                     user_info.profile.image_original || 
                     user_info.profile.image_72 || 
                     user_info.profile.image_48
        end
        
        return {
          user_id: current_user_id,
          username: username,
          user_image: user_image
        }.to_json
      end
    end
    
    # Fallback se não conseguirmos obter as informações do usuário
    return { user_id: current_user_id }.to_json
  end
  
  # Se o Slack não estiver disponível
  status 503
  { error: "Integração com Slack não está disponível" }.to_json
end

post '/add-message' do
  begin
    request.body.rewind
    payload = JSON.parse(request.body.read)
    
    unless payload['original'] && payload['translation']
      status 400
      return { error: "Campos 'original' e 'translation' são obrigatórios" }.to_json
    end
    
    payload['timestamp'] ||= Time.now.to_i
    
    # Guardar todos os campos relevantes do payload, especialmente username e user_image
    message_data = {
      original: payload['original'],
      translation: payload['translation'],
      timestamp: payload['timestamp'],
      # Marcar mensagens adicionadas pelo formulário como enviadas pelo usuário atual
      sent_by_me: true
    }
    
    # Pegar o ID do usuário atual do SlackClient, se disponível
    current_user_id = SlackClient.get_current_user_id
    if current_user_id
      message_data[:user_id] = current_user_id
    elsif payload['user_id']
      message_data[:user_id] = payload['user_id']
    end
    
    # Adicionar explicitamente os dados do usuário se estiverem presentes
    message_data[:username] = payload['username'] if payload['username']
    message_data[:user_image] = payload['user_image'] if payload['user_image']
    
    $logger.info "Adicionando mensagem com username=#{payload['username'] || 'nil'} e user_image=#{payload['user_image'] ? 'presente' : 'ausente'}"
    
    record = Message.create(message_data)
    message_count = Message.count
    
    $logger.info "Mensagem adicionada via API: #{payload['original'][0..30]}..."
    
    content_type :json
    { status: 'ok', message_count: message_count }.to_json
  rescue => e
    status 500
    $logger.error "Erro ao processar mensagem: #{e.message}"
    { error: e.message }.to_json
  end
end

# Rota para traduzir de português para inglês (para a funcionalidade de envio)
post '/translate-to-english' do
  begin
    content_type 'application/json'
    request.body.rewind
    payload = JSON.parse(request.body.read)
    
    unless payload['text']
      status 400
      return { error: "Campo 'text' é obrigatório" }.to_json
    end
    
    # Verificar se o Ollama está disponível
    unless $slack_available
      status 503
      return { error: "Serviço de tradução não está disponível" }.to_json
    end

    # Traduzir o texto de português para inglês
    translation = OllamaClient.translate_pt_to_en(payload['text'])
    
    # Verificar se a tradução foi bem-sucedida
    if translation.include?("[Translation unavailable") || translation.include?("[Translation error")
      status 500
      return { error: translation }.to_json
    end
    
    return { translation: translation }.to_json
  rescue => e
    status 500
    $logger.error "Erro ao traduzir mensagem: #{e.message}"
    return { error: e.message }.to_json
  end
end

# Rota para enviar mensagens traduzidas para o Slack
post '/send-to-slack' do
  begin
    content_type 'application/json'
    request.body.rewind
    payload = JSON.parse(request.body.read)
    
    unless payload['original'] && payload['translation']
      status 400
      return { error: "Campos 'original' e 'translation' são obrigatórios" }.to_json
    end
    
    # Verificar se o Slack está disponível
    unless $slack_available && ENV['SLACK_API_TOKEN'] && ENV['SLACK_CHANNEL_ID']
      status 503
      return { error: "Integração com Slack não está disponível" }.to_json
    end
    
    # Enviar a mensagem para o canal do Slack
    result = SlackClient.send_message_to_channel(payload['translation'])
    
    if result
      # Obter informações do usuário atual do Slack
      current_user_id = SlackClient.get_current_user_id
      $logger.info "Enviando mensagem como usuário #{current_user_id}"
      
      # Verificar se temos o ID do usuário
      if current_user_id
        # Obter detalhes completos do usuário atual
        user_info = SlackClient.get_user_info(current_user_id)
        
        if user_info
          username = user_info.real_name || 
                    (user_info.profile&.display_name if user_info.profile&.display_name&.strip.to_s != '') || 
                    user_info.name
          
          # Buscar a imagem do perfil
          user_image = nil
          if user_info.profile
            user_image = user_info.profile.image_512 || 
                      user_info.profile.image_192 || 
                      user_info.profile.image_original || 
                      user_info.profile.image_72 || 
                      user_info.profile.image_48
          end
          
          $logger.info "Usando detalhes reais do usuário: #{username} (#{current_user_id}) para mensagem enviada via formulário"
          
          # Adicionar a mensagem à lista local com todos os detalhes do usuário
          Message.create(original: payload['original'], translation: payload['translation'], timestamp: Time.now.to_i, user_id: current_user_id, username: username, user_image: user_image, sent_by_me: true)
        else
          # Fallback se não conseguirmos obter detalhes do usuário
          $logger.warn "Não foi possível obter detalhes do usuário #{current_user_id}"
          Message.create(original: payload['original'], translation: payload['translation'], timestamp: Time.now.to_i, user_id: current_user_id, sent_by_me: true)
        end
      else
        # Fallback se não tivermos o ID do usuário
        $logger.warn "ID do usuário atual não disponível para mensagem enviada via formulário"
        Message.create(original: payload['original'], translation: payload['translation'], timestamp: Time.now.to_i, sent_by_me: true)
      end
      
      $logger.info "Mensagem enviada ao Slack: #{payload['translation'][0..30]}..."
      return { success: true }.to_json
    else
      status 500
      return { error: "Falha ao enviar mensagem para o Slack" }.to_json
    end
  rescue => e
    status 500
    $logger.error "Erro ao enviar mensagem para o Slack: #{e.message}"
    return { error: e.message }.to_json
  end
end
