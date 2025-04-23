require 'dotenv/load'
require 'sinatra'
require 'json'
require 'logger'

begin
  require_relative 'lib/slack_client'
  require_relative 'lib/ollama_client'
  $slack_available = true
rescue LoadError => e
  puts "Aviso: Não foi possível carregar biblioteca: #{e.message}"
  $slack_available = false
end

set :port, 3000
set :bind, '0.0.0.0'
set :environment, :development
set :public_folder, File.expand_path('../public', __FILE__)
set :views, File.expand_path('../views', __FILE__)
set :logging, true

$messages = [
  {original: "Hello world", translation: "Olá mundo", timestamp: Time.now.to_i - 120},
  {original: "This is a test message", translation: "Esta é uma mensagem de teste", timestamp: Time.now.to_i - 60},
  {original: "Welcome to SlackTranslator", translation: "Bem-vindo ao SlackTranslator", timestamp: Time.now.to_i}
]

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
  $messages.to_json
end

get '/test-message' do
  original = "This is a test message! #{Time.now.strftime('%H:%M:%S')}"
  translation = "Esta é uma mensagem de teste! #{Time.now.strftime('%H:%M:%S')}"
  
  $messages << {original: original, translation: translation, timestamp: Time.now.to_i}
  
  $messages = $messages.last(20) if $messages.size > 20
  
  content_type :json
  { status: 'ok', message: 'Test message sent', original: original, translation: translation }.to_json
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
    message_count: $messages.size,
    slack_available: $slack_available
  }.to_json
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
    
    $messages << {
      original: payload['original'],
      translation: payload['translation'],
      timestamp: payload['timestamp']
    }
    
    $messages = $messages.last(50) if $messages.size > 50
    
    $logger.info "Mensagem adicionada via API: #{payload['original'][0..30]}..."
    
    content_type :json
    { status: 'ok', message_count: $messages.size }.to_json
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
      # Adicionar a mensagem à lista local para exibição
      $messages << {
        original: payload['original'],
        translation: payload['translation'],
        timestamp: Time.now.to_i,
        sent_by_user: true
      }
      
      $messages = $messages.last(50) if $messages.size > 50
      
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
