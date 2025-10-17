# PDF AI Notes - Python Server Documentation

## Overview

A stateless FastAPI server that receives extracted PDF text from Hammerspoon and generates structured notes using AI (via OpenRouter). The server processes raw PDF text (including broken LaTeX), cleans it up, and returns markdown-formatted notes optimized for Obsidian.

**Version:** 0.1.0
**Python:** 3.14
**Package Manager:** uv

---

## Architecture

### Design Principles

1. **Stateless Server** - No database access, pure text processing
2. **Synchronous Processing** - Simple request/response model
3. **OpenRouter Integration** - Uses free AI models via OpenAI-compatible API
4. **Hardcoded Prompts** - MVP uses predefined templates (extensible later)
5. **Single Responsibility** - Server only generates notes, Lua handles storage

### Tech Stack

- **FastAPI** - Modern async web framework
- **OpenAI SDK** - Client for OpenRouter API
- **Pydantic** - Data validation and settings management
- **Uvicorn** - ASGI server with auto-reload

### Request Flow

```
Hammerspoon (Lua)
    │
    ├─ Extract PDF text
    ├─ Sanitize text
    │
    ▼
Python Server (FastAPI)
    │
    ├─ Receive text + context
    ├─ Build prompt
    ├─ Call OpenRouter API
    ├─ Return formatted notes
    │
    ▼
Hammerspoon (Lua)
    │
    ├─ Receive notes
    └─ Store in SQLite database
```

---

## Project Structure

```
python/
├── main.py              # FastAPI app and endpoints
├── config.py            # Settings from environment variables
├── models.py            # Pydantic request/response schemas
├── prompts.py           # AI prompt templates
├── pyproject.toml       # uv dependencies
├── .env                 # API keys (gitignored)
├── .env.example         # Template for .env
├── .python-version      # Python version (3.14)
└── documentation.md     # This file
```

---

## Current Implementation

### 1. Configuration (`config.py`)

Loads settings from environment variables using `pydantic-settings`.

**Settings:**
- `openrouter_api_key` - Your OpenRouter API key
- `model_name` - AI model to use (default: `google/gemini-flash-1.5-8b`)
- `max_tokens` - Maximum response length (default: 2000)
- `temperature` - Response creativity (default: 0.3 for focused summaries)
- `host`, `port` - Server configuration

**Environment Variables:**
```bash
OPENROUTER_API_KEY=sk-or-v1-xxxxx
MODEL_NAME=google/gemini-flash-1.5-8b  # Optional override
```

### 2. Data Models (`models.py`)

**`SummarizeRequest`:**
- `text` (required) - Extracted PDF text
- `pdf_name` (optional) - PDF filename for context
- `page_number` (optional) - Page number for context

**`SummarizeResponse`:**
- `summary` - Generated markdown notes
- `success` - Boolean status
- `error` - Error message if failed

### 3. Prompt Templates (`prompts.py`)

**System Prompt:**
- Specialized for academic/technical content
- Handles broken LaTeX from PDF extraction
- Formats output for Obsidian (markdown + LaTeX)
- Organizes hierarchically with clear structure

**User Prompt Builder:**
- Includes document context (filename, page number)
- Wraps extracted text
- Instructs AI to follow system prompt format

### 4. API Endpoints (`main.py`)

#### `GET /health`
Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "model": "google/gemini-flash-1.5-8b",
  "version": "0.1.0"
}
```

#### `POST /api/summarize`
Generate structured notes from PDF text.

**Request:**
```json
{
  "text": "Neural networks are computational models...",
  "pdf_name": "deep_learning.pdf",
  "page_number": 42
}
```

**Response (Success):**
```json
{
  "summary": "## Key Concepts\n\n- **Neural Networks**: Computational models...",
  "success": true,
  "error": null
}
```

**Response (Error):**
```json
{
  "summary": null,
  "success": false,
  "error": "Summarization failed: API timeout"
}
```

---

## Setup & Usage

### Installation

```bash
cd python

# Install dependencies
uv sync

# Create environment file
cp .env.example .env

# Edit .env and add your OpenRouter API key
# Get free key at: https://openrouter.ai/keys
```

### Running the Server

**Development (auto-reload):**
```bash
uv run fastapi dev main.py
```

**Production:**
```bash
uv run fastapi run main.py
```

**Direct with uvicorn:**
```bash
uv run python main.py
```

Server runs at: `http://localhost:8000`

### Testing

**Health check:**
```bash
curl http://localhost:8000/health
```

**Summarize text:**
```bash
curl -X POST http://localhost:8000/api/summarize \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Your PDF text here...",
    "pdf_name": "example.pdf",
    "page_number": 1
  }'
```

**Interactive API docs:**
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

---

## AI Model Options

### Current: Free OpenRouter Models

**Recommended:**
- `google/gemini-flash-1.5-8b` (best free option)
- `google/gemini-flash-1.5` (higher quality)

**Alternatives:**
- `meta-llama/llama-3.2-3b-instruct:free`
- `qwen/qwen-2.5-7b-instruct:free`
- `mistralai/mistral-7b-instruct:free`

### Changing Models

Edit `.env`:
```bash
MODEL_NAME=google/gemini-flash-1.5
```

Or use paid models for better quality:
```bash
MODEL_NAME=anthropic/claude-3.5-sonnet
```

---

## Integration with Hammerspoon

### Current State
- Hammerspoon extracts and sanitizes PDF text
- TODO: Send HTTP POST to `/api/summarize`
- TODO: Store returned notes in SQLite database

### Implementation Plan

**In `preview_poller.lua`:**

```lua
-- After extracting text (around line 27)
local function sendToAI(pdfId, pageNumber, pdfPath, pageText)
    local payload = {
        text = pageText,
        pdf_name = pdfPath:match("([^/]+)$"),
        page_number = pageNumber
    }

    hs.http.asyncPost(
        "http://localhost:8000/api/summarize",
        hs.json.encode(payload),
        {["Content-Type"] = "application/json"},
        function(status, body, headers)
            if status == 200 then
                local response = hs.json.decode(body)
                if response.success then
                    -- Store notes in database
                    local pageId = db.getPageId(pdfId, pageNumber)
                    db.storeNote(pageId, response.summary, "summary", "default")
                    print("Notes stored successfully")
                else
                    print("Error: " .. response.error)
                end
            else
                print("HTTP error: " .. status)
            end
        end
    )
end
```

---

## Future Enhancements

### Phase 2: Enhanced Note Generation

1. **Multiple Note Types**
   - Summary (current)
   - Detailed notes
   - Flashcards
   - Mind maps
   - LaTeX-only cleanup

2. **Directives System**
   - Database-driven prompts (from Lua `directives` table)
   - Custom user prompts
   - Context-aware generation

3. **Concept Extraction**
   - Parse AI response for key concepts
   - Return structured concept list
   - Link concepts across documents

### Phase 3: Advanced Features

1. **Batch Processing**
   - Process multiple pages in parallel
   - Queue system for large documents
   - Progress tracking

2. **Caching Layer**
   - Cache processed pages (optional)
   - Invalidate on PDF modification
   - Reduce API costs

3. **Image Analysis**
   - Extract images from PDFs
   - OCR for handwritten notes
   - Diagram descriptions
   - Chart data extraction

4. **Contextual Notes**
   - Cross-reference previous pages
   - Build document-wide knowledge graph
   - Smart chapter summaries

5. **Learning Analytics**
   - Track which concepts need review
   - Spaced repetition integration
   - Reading pattern analysis

### Phase 4: API Expansion

1. **New Endpoints**
   - `POST /api/flashcards` - Generate Q&A pairs
   - `POST /api/concepts` - Extract concept graph
   - `POST /api/cleanup-latex` - LaTeX-only processing
   - `GET /api/models` - List available AI models
   - `POST /api/validate` - Pre-check text before processing

2. **Configuration API**
   - `GET /api/directives` - Fetch available prompts
   - `POST /api/directives` - Add custom prompts
   - `GET /api/settings` - Server configuration

3. **Webhook Support**
   - Async processing with callbacks
   - Progress notifications
   - Batch completion events

### Phase 5: Quality Improvements

1. **Error Handling**
   - Retry logic with exponential backoff
   - Fallback models on failure
   - Partial response recovery

2. **Validation**
   - Check LaTeX syntax in responses
   - Markdown structure validation
   - Concept quality scoring

3. **Optimization**
   - Response streaming for long notes
   - Token usage optimization
   - Request batching

4. **Monitoring**
   - Request metrics (latency, errors)
   - Model performance tracking
   - Cost monitoring (token usage)
   - Health checks with detailed status

### Phase 6: Alternative Backends

1. **Local Models**
   - Ollama integration
   - LM Studio support
   - No API costs, full privacy

2. **Multi-Provider Support**
   - Switch between OpenRouter/Anthropic/OpenAI
   - Cost optimization routing
   - Fallback chains

---

## Configuration Reference

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OPENROUTER_API_KEY` | Yes | - | Your OpenRouter API key |
| `MODEL_NAME` | No | `google/gemini-flash-1.5-8b` | AI model to use |
| `MAX_TOKENS` | No | `2000` | Maximum response length |
| `TEMPERATURE` | No | `0.3` | Response creativity (0.0-1.0) |
| `HOST` | No | `127.0.0.1` | Server host |
| `PORT` | No | `8000` | Server port |
| `LOG_LEVEL` | No | `info` | Logging level |

### Prompt Customization

To customize the AI behavior, edit `prompts.py`:

**System Prompt** - Controls overall behavior
**User Prompt Template** - Controls request format

---

## Troubleshooting

### Server won't start

**Error: "openrouter_api_key not found"**
- Check `.env` file exists
- Verify `OPENROUTER_API_KEY` is set
- Try: `export OPENROUTER_API_KEY=your-key` before running

**Error: Import errors**
- Run `uv sync` to install dependencies
- Check Python version: `python --version` (should be 3.14)

### API Errors

**429: Rate Limited**
- Free tier has limits (~10 req/min)
- Add delays between requests
- Consider upgrading OpenRouter plan

**Empty or bad responses**
- Try different model in `.env`
- Check input text quality
- Increase `MAX_TOKENS` setting

**Timeout errors**
- Increase timeout in request
- Try faster model (gemini-flash vs gemini-pro)
- Check OpenRouter status

---

## Development

### Adding Dependencies

```bash
uv add package-name
```

### Code Style

- Use type hints
- Follow PEP 8
- Document with docstrings
- Async where beneficial

### Testing

```bash
# Install test dependencies (future)
uv add --dev pytest pytest-asyncio httpx

# Run tests (future)
uv run pytest
```

---

## Security Considerations

1. **API Keys** - Never commit `.env` to git
2. **CORS** - Currently allows all origins (change for production)
3. **Rate Limiting** - Not implemented (add for production)
4. **Input Validation** - Pydantic handles basic validation
5. **Output Sanitization** - AI responses should be validated

---

## Performance

**Current Performance (MVP):**
- Request latency: 5-30 seconds (depends on AI model)
- Throughput: ~1-2 requests/sec (single-threaded)
- Memory: ~50-100MB base + per-request overhead

**Optimization Opportunities:**
- Connection pooling for HTTP client
- Response caching
- Async processing with queues
- Multiple worker processes

---

## Contributing

When extending this server:

1. Follow existing code structure
2. Add new endpoints in `main.py`
3. Create new schemas in `models.py`
4. Add prompts to `prompts.py`
5. Document changes in this file
6. Test thoroughly before committing

---

## Resources

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [OpenRouter Docs](https://openrouter.ai/docs)
- [uv Documentation](https://docs.astral.sh/uv/)
- [Pydantic Settings](https://docs.pydantic.dev/latest/concepts/pydantic_settings/)

---

**Last Updated:** October 2025
**Status:** MVP Complete - Ready for Hammerspoon Integration
