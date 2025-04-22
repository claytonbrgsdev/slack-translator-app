# SlackTranslator

## Português

Comunicação multilíngue em tempo real para o Slack que traduz automaticamente mensagens entre inglês e português.

### Funcionalidades

- Tradução de mensagens do Slack em tempo real
- Interface de duas colunas mostrando mensagens originais e traduzidas
- Composição de respostas no idioma nativo com confirmação
- Eventos Server-Sent (SSE) para atualizações ao vivo

### Requisitos

- Ruby 3.0+
- Ollama rodando localmente
- Token da API do Slack

### Configuração

1. Clone o repositório
2. Execute `bundle install`
3. Copie `.env.example` para `.env` e preencha suas credenciais (veja a seção "Configuração de Variáveis de Ambiente" abaixo)
4. Inicie o servidor com `bundle exec rackup`

### Configuração de Variáveis de Ambiente

Antes de executar a aplicação, copie o arquivo `.env.example` para `.env` e configure as seguintes variáveis:

#### Credenciais do Slack

Para obter estas credenciais, você precisa criar uma aplicação Slack em https://api.slack.com/apps

1. **SLACK_APP_ID**: ID da sua aplicação Slack
   * Disponível em: _Basic Information_ > _App Credentials_ > _App ID_

2. **SLACK_CLIENT_ID**: Client ID da sua aplicação Slack
   * Disponível em: _Basic Information_ > _App Credentials_ > _Client ID_

3. **SLACK_API_TOKEN**: Token de autenticação do Bot
   * Disponível em: _OAuth & Permissions_ > _Bot User OAuth Token_
   * Certifique-se de que seu bot tenha as permissões: `channels:history`, `channels:read`, `chat:write`

4. **SLACK_CHANNEL_ID**: ID do canal que será monitorado
   * No Slack, clique com o botão direito no canal > _Copiar link_
   * O ID é a última parte da URL (começa com "C")

#### Configuração do Ollama

5. **OLLAMA_API_URL**: URL da API do Ollama (opcional)
   * Valor padrão: `http://localhost:11434`
   * Altere apenas se o Ollama estiver rodando em outra máquina/porta

### Uso

1. Inicie a aplicação
2. Conecte-se à interface web
3. Mensagens do canal Slack configurado aparecerão em tempo real
4. Componha respostas em português que serão traduzidas para inglês

### Desenvolvimento

Execute testes com:
```
bundle exec rspec
```

---

## English

Real-time multilingual communication for Slack that automatically translates messages between English and Portuguese.

### Features

- Real-time Slack message translation
- Two-column interface showing original and translated messages
- Reply composition in native language with confirmation
- Server-Sent Events for live updates

### Requirements

- Ruby 3.0+
- Ollama running locally
- Slack API token

### Setup

1. Clone the repository
2. Run `bundle install`
3. Copy `.env.example` to `.env` and fill in your credentials (see "Environment Variables Configuration" section below)
4. Start the server with `bundle exec rackup`

### Environment Variables Configuration

Before running the application, copy the `.env.example` file to `.env` and configure the following variables:

#### Slack Credentials

To obtain these credentials, you need to create a Slack application at https://api.slack.com/apps

1. **SLACK_APP_ID**: Your Slack application ID
   * Available at: _Basic Information_ > _App Credentials_ > _App ID_

2. **SLACK_CLIENT_ID**: Your Slack application Client ID
   * Available at: _Basic Information_ > _App Credentials_ > _Client ID_

3. **SLACK_API_TOKEN**: Bot authentication token
   * Available at: _OAuth & Permissions_ > _Bot User OAuth Token_
   * Make sure your bot has the permissions: `channels:history`, `channels:read`, `chat:write`

4. **SLACK_CHANNEL_ID**: ID of the channel to be monitored
   * In Slack, right-click on the channel > _Copy link_
   * The ID is the last part of the URL (starts with "C")

#### Ollama Configuration

5. **OLLAMA_API_URL**: Ollama API URL (optional)
   * Default value: `http://localhost:11434`
   * Change only if Ollama is running on another machine/port

### Usage

1. Start the application
2. Connect to the web interface
3. Messages from the configured Slack channel will appear in real-time
4. Compose replies in Portuguese which will be translated back to English

### Development

Run tests with:
```
bundle exec rspec
