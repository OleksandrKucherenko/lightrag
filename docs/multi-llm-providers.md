# Multi-LLM Provider Configuration

This document explains how to configure LightRAG to work with different LLM providers: OpenAI, Ollama, and OpenRouter.ai.

## Supported Providers

### 1. OpenAI (Default)
- **Best for**: Production use, reliable performance
- **Models**: gpt-4o-mini, gpt-4, text-embedding-3-small
- **Requirements**: API key from https://platform.openai.com/api-keys

### 2. Ollama
- **Best for**: Local development, privacy, cost control
- **Models**: llama2, codellama, mistral, and many others
- **Requirements**: Ollama server running locally

### 3. OpenRouter.ai
- **Best for**: Access to multiple models, competitive pricing
- **Models**: Claude, Gemini, Llama, and many others
- **Requirements**: API key from https://openrouter.ai/keys

## Configuration

### Environment Variables

Update your `.env` file with the appropriate provider settings:

```bash
# OpenAI Configuration
LLM_BINDING=openai
LLM_MODEL=gpt-4o-mini
LLM_BINDING_HOST=https://api.openai.com/v1
EMBEDDING_BINDING=openai
EMBEDDING_MODEL=text-embedding-3-small

# Ollama Configuration
LLM_BINDING=ollama
LLM_MODEL=llama2:7b
LLM_BINDING_HOST=http://ollama:11434
EMBEDDING_BINDING=ollama
EMBEDDING_MODEL=nomic-embed-text

# OpenRouter Configuration
LLM_BINDING=openrouter
LLM_MODEL=meta-llama/llama-3.1-8b-instruct
LLM_BINDING_HOST=https://openrouter.ai/api/v1
EMBEDDING_BINDING=openai  # OpenRouter doesn't provide embeddings
EMBEDDING_MODEL=text-embedding-3-small
```

### Docker Compose Updates

For Ollama support, add the Ollama service to your `docker-compose.yaml`:

```yaml
# Add this service for Ollama support
ollama:
  image: ollama/ollama:latest
  container_name: ollama
  restart: unless-stopped
  volumes:
    - ollama_data:/root/.ollama
  networks:
    - backend
  ports:
    - 11434:11434
  labels:
    caddy: "https://ollama.${PUBLISH_DOMAIN}"
    caddy.tls: "/ssl/dev.localhost.pem /ssl/dev.localhost-key.pem"
    caddy.reverse_proxy: "{{upstreams 11434}}"
  deploy: *deploy-medium
  logging: *default-logging

volumes:
  ollama_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ./docker/data/ollama
```

## Provider-Specific Setup

### OpenAI Setup

1. Get your API key from https://platform.openai.com/api-keys
2. Add to your secrets file:
   ```bash
   LLM_BINDING_API_KEY=sk-your-openai-api-key
   EMBEDDING_BINDING_API_KEY=sk-your-openai-api-key  # Same key for both
   ```

### Ollama Setup

1. Pull required models:
   ```bash
   # For LLM
   docker exec ollama ollama pull llama2:7b

   # For embeddings
   docker exec ollama ollama pull nomic-embed-text
   ```

2. No API key required for local Ollama

### OpenRouter Setup

1. Get your API key from https://openrouter.ai/keys
2. Add to your secrets file:
   ```bash
   LLM_BINDING_API_KEY=sk-or-v1-your-openrouter-api-key
   EMBEDDING_BINDING_API_KEY=sk-your-openai-api-key  # Still need OpenAI for embeddings
   ```

## Verification Commands

### Test LLM Provider

```bash
# Test OpenAI
curl -X POST https://api.${PUBLISH_DOMAIN}/v1/chat/completions \
  -H "Authorization: Bearer $LLM_BINDING_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "gpt-4o-mini", "messages": [{"role": "user", "content": "Hello"}]}'

# Test Ollama
curl -X POST http://ollama:11434/api/chat \
  -H "Content-Type: application/json" \
  -d '{"model": "llama2:7b", "messages": [{"role": "user", "content": "Hello"}]}'
```

### Test Embeddings

```bash
# Test OpenAI embeddings
curl -X POST https://api.${PUBLISH_DOMAIN}/v1/embeddings \
  -H "Authorization: Bearer $EMBEDDING_BINDING_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"input": "Test document", "model": "text-embedding-3-small"}'

# Test Ollama embeddings
curl -X POST http://ollama:11434/api/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model": "nomic-embed-text", "prompt": "Test document"}'
```

### Test LobeChat Integration

```bash
# Test LobeChat with current provider
curl -X POST https://chat.${PUBLISH_DOMAIN}/api/chat \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "What is RAG?"}]}'
```

## Troubleshooting

### Common Issues

1. **API Key Issues**
   - Verify API keys are correctly set in environment variables
   - Check API key permissions and quotas

2. **Network Connectivity**
   - Ensure services can reach each other in Docker network
   - Check firewall settings for external API calls

3. **Model Compatibility**
   - Verify model names match provider specifications
   - Check model availability and version compatibility

### Debug Commands

```bash
# Check LightRAG logs
docker compose logs rag

# Check LobeChat logs
docker compose logs lobechat

# Test direct API access
docker compose exec rag curl -s http://localhost:9621/health

# Check environment variables in containers
docker compose exec rag env | grep -E "(LLM|EMBEDDING)_"
```

## Performance Considerations

### OpenAI
- Fastest response times
- Most reliable for production
- Higher costs for heavy usage

### Ollama
- No API costs
- Requires more local resources
- Slower response times

### OpenRouter
- Access to many models
- Competitive pricing
- Variable performance depending on model

## Security Notes

- Store API keys securely using Mise secrets
- Use different keys for development and production
- Monitor API usage and costs
- Rotate keys regularly