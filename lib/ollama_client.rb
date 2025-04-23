require 'http'
require 'json'
require 'logger'

module OllamaClient
  API_BASE = ENV.fetch('OLLAMA_API_URL', 'http://localhost:11434')
  
  @@logger = Logger.new(STDOUT)
  @@available = nil # Estado do serviço ainda não testado
  
  def self.available?
    @@available = nil
    
    begin
      models_url = "#{API_BASE}/api/tags"
      @@logger.info "Verificando modelos Ollama em: #{models_url}"
      
      response = HTTP.timeout(2).get(models_url)
      
      if response.status.success?
        models = JSON.parse(response.to_s)['models'] || []
        @@logger.info "Serviço Ollama disponível com #{models.size} modelos"
        @@available = true
      else
        @@logger.error "Erro na API Ollama: #{response.status}"
        @@available = false 
      end
    rescue => e
      @@logger.error "Erro ao verificar disponibilidade do Ollama: #{e.message}"
      @@available = false
    end
    
    @@available
  end
  
  def self.available_models
    begin
      response = HTTP.timeout(2).get("#{API_BASE}/api/tags")
      if response.status.success?
        models = JSON.parse(response.to_s)['models'] || []
        models.map { |m| m['name'] }
      else
        []
      end
    rescue
      []
    end
  end
  
  def self.select_model
    models = available_models
    preferences = ['llama3.1:8b', 'llama3', 'llama2', 'mistral', 'deepseek']
    
    selected = nil
    preferences.each do |pref|
      match = models.find { |m| m.include?(pref) }
      if match
        selected = match
        break
      end
    end
    
    selected || models.first
  end

  def self.translate_en_to_pt(text)
    return "[Tradução indisponível - Ollama não está rodando]" unless available?
    
    begin
      generate_url = "#{API_BASE}/api/generate"
      
      model = select_model
      @@logger.info "Enviando tradução para: #{generate_url} usando modelo: #{model || 'padrão'}"
      
      payload = { 
        model: model || 'llama3.1:8b', 
        prompt: "Translate the following English text to Brazilian Portuguese. Return ONLY the direct translation without ANY additional comments, explanations, introductory phrases, or cultural notes. The output should contain only the translated content and nothing else:\n\n#{text}", 
        stream: false 
      }
      
      response = HTTP.timeout(15).post(generate_url, json: payload)
      @@logger.info "Resposta recebida: #{response.status}"
      
      if response.status.success?
        parsed = JSON.parse(response.to_s)
        if parsed['response']
          return parsed['response']
        else
          @@logger.error "Resposta do Ollama sem campo 'response': #{parsed.inspect}"
          return "[Formato inesperado na resposta]"
        end
      else
        @@logger.error "Erro na API Ollama: #{response.status} - #{response.body}"
        "[Erro na tradução - #{response.status}]"
      end
    rescue => e
      @@logger.error "Erro ao traduzir com Ollama: #{e.message}"
      "[Erro na tradução] #{e.message.split(' at ').first}"
    end
  end
  
  def self.translate_pt_to_en(text)
    return "[Translation unavailable - Ollama is not running]" unless available?
    
    begin
      generate_url = "#{API_BASE}/api/generate"
      
      model = select_model
      @@logger.info "Enviando tradução para: #{generate_url} usando modelo: #{model || 'padrão'}"
      
      payload = { 
        model: model || 'llama3.1:8b', 
        prompt: "Translate the following Portuguese text to English. Return ONLY the direct translation without ANY additional comments, explanations, introductory phrases, or cultural notes. The output should contain only the translated content and nothing else:\n\n#{text}", 
        stream: false 
      }
      
      response = HTTP.timeout(15).post(generate_url, json: payload)
      
      if response.status.success?
        parsed = JSON.parse(response.to_s)
        if parsed['response']
          return parsed['response']
        else
          @@logger.error "Resposta do Ollama sem campo 'response': #{parsed.inspect}"
          return "[Unexpected response format]"
        end
      else
        @@logger.error "Erro na API Ollama: #{response.status} - #{response.body}"
        "[Translation error - #{response.status}]"
      end
    rescue => e
      @@logger.error "Erro ao traduzir com Ollama: #{e.message}"
      "[Translation error] #{e.message.split(' at ').first}"
    end
  end
end
