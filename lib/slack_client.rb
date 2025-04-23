require 'slack-ruby-client'
require 'logger'
require 'json'
require 'net/http'
require_relative 'ollama_client'

module SlackClient
  class << self
    attr_accessor :web_client, :logger, :last_timestamp, :current_user_id
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
      @current_user_id = auth_test.user_id # Armazenar o ID do usuário atual
      @logger.info "Conectado ao Slack como: #{auth_test.user} (#{auth_test.team}) ID: #{@current_user_id}"
      
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
            
            # Passar o ID do usuário para o process_message
            # Não incluir o nome do usuário no texto da mensagem para evitar repetição
            # O nome será exibido apenas ao lado do avatar
            process_message(msg.ts, msg.text, msg.user)
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
  
  def self.is_current_user?(user_id)
    # Verificar se o ID do usuário fornecido corresponde ao usuário atual (você)
    # Logs detalhados para depurar o problema de identificação incorreta
    @logger ||= Logger.new(STDOUT)
    
    if !@current_user_id
      @logger.warn "PROBLEMA: current_user_id não está definido. Nenhuma mensagem pode ser do usuário atual."
      return false
    end
    
    if !user_id
      @logger.warn "PROBLEMA: user_id não fornecido para comparar com current_user_id."
      return false
    end
    
    result = @current_user_id.to_s.strip == user_id.to_s.strip
    
    @logger.info "COMPARAÇÃO DE IDs: current_user_id='#{@current_user_id.to_s}' vs user_id='#{user_id.to_s}' => #{result ? 'MATCH' : 'DIFFERENT'}"
    
    # Garante que identificamos corretamente o usuário atual
    return result
  end

  def self.get_current_user_id
    # Retornar o ID do usuário atual (você)
    return @current_user_id
  end

  def self.get_user_info(user_id)
    begin
      return nil unless user_id
      
      @logger.info "Solicitando informações do usuário para ID: #{user_id}"
      response = @web_client.users_info(user: user_id)
      
      if response && response.ok && response.user
        user = response.user
        @logger.info "Informações do usuário recebidas para ID #{user_id}: Nome: #{user.real_name}, Display name: #{user.profile&.display_name}, Nome comum: #{user.name}"
        
        # Verificação detalhada das propriedades do perfil para debug
        if user.profile
          profile_keys = user.profile.to_h.keys
          @logger.info "Perfil do usuário contém as seguintes propriedades: #{profile_keys.join(', ')}"
          
          # Verificar todas as opções de imagem de perfil
          image_keys = profile_keys.select { |k| k.to_s.start_with?('image') }
          @logger.info "Chaves de imagem disponíveis: #{image_keys.join(', ')}"
          
          # Log das URLs das imagens para depuração
          image_keys.each do |key|
            @logger.info "  #{key}: #{user.profile[key]}"
          end
        else
          @logger.warn "Usuário #{user_id} não possui objeto de perfil"
        end
      else
        error_msg = response ? response.error : "Resposta nula"
        @logger.error "Falha ao obter informações do usuário. Erro: #{error_msg}"
        return nil
      end
      
      return user
    rescue => e
      @logger.error "Exceção ao obter informações do usuário #{user_id}: #{e.message}"
      @logger.error "Stack trace: #{e.backtrace.join('\n')}"
      nil
    end
  end

  def self.process_message(ts, text, user_id=nil)
    original = text
    @logger.info "Processando mensagem: #{original[0..30]}..."
    
    # Extrair o nome de usuário e ID, caso já não tenham sido fornecidos
    user_info = nil
    username = nil
    user_image = nil
    
    # Se a mensagem estiver no formato "Username: message", extrair o username e a mensagem
    if original =~ /^(.+?):\s*(.+)$/ && !user_id
      username = $1
      message_text = $2
      # Procurar pelo ID do usuário pelos nomes
      begin
        users_list = @web_client.users_list
        users_list.members.each do |user|
          if user.real_name == username || user.name == username
            user_id = user.id
            break
          end
        end
      rescue => e
        @logger.error "Erro ao buscar usuário por nome: #{e.message}"
      end
    else
      message_text = original
    end
    
    # Obter informações do usuário se tivermos um ID
    if user_id
      user_info = get_user_info(user_id)
      
      if user_info
        # Priorizar real_name que é o nome completo, depois display_name do perfil, por último o nome do usuário
        username = user_info.real_name || 
                   (user_info.profile&.display_name if user_info.profile&.display_name&.strip.to_s != '') || 
                   user_info.name
        
        @logger.info "Usando nome de usuário: '#{username}' para o ID: #{user_id}"
        
        # Capturar a URL da imagem do perfil
        if user_info.profile
          @logger.info "Perfil de usuário encontrado para #{username}"
          
          # Tentar obter a URL da imagem em vários tamanhos possíveis
          # Prioriza tamanhos maiores para melhor qualidade visual
          user_image = user_info.profile.image_512 || 
                       user_info.profile.image_192 || 
                       user_info.profile.image_original || 
                       user_info.profile.image_72 || 
                       user_info.profile.image_48
          
          if user_image
            @logger.info "URL da imagem do perfil encontrada: #{user_image}"
          else
            available_fields = user_info.profile.to_h.keys.join(', ')
            @logger.warn "Nenhuma URL de imagem encontrada no perfil. Campos disponíveis: #{available_fields}"
            
            # Tentar qualquer campo que contenha "image" no nome
            image_fields = user_info.profile.to_h.select { |k, _| k.to_s.include?("image") }
            if image_fields.any?
              first_image_key = image_fields.keys.first
              user_image = user_info.profile[first_image_key]
              @logger.info "Usando campo alternativo de imagem #{first_image_key}: #{user_image}"
            end
          end
        else
          @logger.warn "Objeto de perfil não encontrado para #{username}"
        end
      else
        @logger.warn "Não foi possível obter informações do usuário para ID: #{user_id}"
      end
    end
    
    begin
      @logger.info "Traduzindo mensagem via Ollama..."
      translation = OllamaClient.translate_en_to_pt(original)
      @logger.info "Tradução concluída: #{translation[0..30]}..."
    rescue => e
      @logger.error "Erro na tradução: #{e.message}"
      translation = "[Erro na tradução] #{original}"
    end
    
    begin
      # Verificar se a mensagem foi enviada pelo usuário atual (você)
    is_current_user = is_current_user?(user_id)
    @logger.info "Verificando se mensagem é do usuário atual: #{is_current_user} (user_id: #{user_id}, current_user_id: #{@current_user_id})"
    
    # Criar a mensagem com todos os dados relevantes
    message = { 
      original: original, 
      translation: translation, 
      timestamp: Time.now.to_i,
      user_id: user_id,
      username: username,
      user_image: user_image,
      sent_by_me: is_current_user # Adicionar flag para identificar mensagens do usuário atual
    }
      
      @logger.info "Enviando mensagem com informações de usuário: ID=#{user_id}, Nome=#{username}, Tem imagem=#{!user_image.nil?}"
      
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
  
  def self.test_message(text="Hello, this is a test message from Slack.")
    ts = Time.now.to_f.to_s
    @logger ||= Logger.new(STDOUT)
    
    # Obter as informações do bot atual que está enviando a mensagem
    begin
      @logger.info "Obtendo informações do bot para mensagem de teste"
      auth_test = @web_client.auth_test
      if auth_test && auth_test.ok
        bot_user_id = auth_test.user_id
        @logger.info "ID do bot encontrado: #{bot_user_id}"
        
        # Processar mensagem usando o ID real do bot
        process_message(ts, text, bot_user_id)
        return true
      else
        @logger.error "Não foi possível obter informações do bot: #{auth_test.error if auth_test}"
      end
    rescue => e
      @logger.error "Erro ao obter informações do bot para mensagem de teste: #{e.message}"
    end
    
    # Fallback: se não conseguir obter as informações do bot, usar o processo normal
    @logger.info "Usando método de fallback para mensagem de teste"
    process_message(ts, text)
  end
  
  # Método para enviar mensagens para o canal do Slack
  def self.send_message_to_channel(text)
    @logger ||= Logger.new(STDOUT)
    
    # Verificar se temos um cliente Slack inicializado
    unless @web_client
      @logger.error "Cliente Slack não está inicializado"
      return false
    end
    
    begin
      channel_id = ENV['SLACK_CHANNEL_ID']
      
      # Verificar se temos um token de usuário disponível
      if ENV['SLACK_USER_TOKEN'] && !ENV['SLACK_USER_TOKEN'].empty?
        # Criar um cliente Slack usando o token de usuário
        @logger.info "Usando token de usuário para enviar mensagem como você mesmo"
        user_client = Slack::Web::Client.new(token: ENV['SLACK_USER_TOKEN'])
        
        @logger.info "Enviando mensagem como usuário para o canal Slack #{channel_id}: #{text[0..30]}..."
        
        response = user_client.chat_postMessage(
          channel: channel_id,
          text: text,
          as_user: true  # Isso garante que a mensagem seja enviada como o usuário, não como o bot
        )
      else
        # Usar o cliente do bot (comportamento padrão)
        @logger.info "Usando token do bot para enviar mensagem (SLACK_USER_TOKEN não configurado)"
        @logger.info "Enviando mensagem como bot para o canal Slack #{channel_id}: #{text[0..30]}..."
        
        response = @web_client.chat_postMessage(
          channel: channel_id,
          text: text,
          as_user: true
        )
      end
      
      if response && response.ok
        @logger.info "Mensagem enviada com sucesso para o Slack: #{response.ts}"
        return true
      else
        @logger.error "Erro ao enviar mensagem para o Slack: #{response.error || 'Erro desconhecido'}"
        return false
      end
    rescue => e
      @logger.error "Erro ao enviar mensagem para o Slack: #{e.message}"
      return false
    end
  end
end
