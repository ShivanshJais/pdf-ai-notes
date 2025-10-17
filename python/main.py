"""FastAPI server for PDF AI Notes - OpenRouter integration."""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from openai import OpenAI

from config import settings
from models import SummarizeRequest, SummarizeResponse
from prompts import SUMMARIZE_SYSTEM_PROMPT, build_summarize_prompt

# Configure logging
logging.basicConfig(
    level=settings.log_level.upper(),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

# Global OpenAI client (configured for OpenRouter)
client: OpenAI | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifecycle manager for FastAPI app."""
    global client

    # Startup: Initialize OpenRouter client
    logger.info("Initializing OpenRouter client...")
    client = OpenAI(
        base_url=settings.openrouter_base_url,
        api_key=settings.openrouter_api_key,
    )
    logger.info(f"Using model: {settings.model_name}")

    yield

    # Shutdown: Cleanup if needed
    logger.info("Shutting down server...")


# Create FastAPI app
app = FastAPI(
    title="PDF AI Notes API",
    description="AI-powered note generation for PDF reading",
    version="0.1.0",
    lifespan=lifespan,
)

# Add CORS middleware for local development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your Hammerspoon origin
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "model": settings.model_name,
        "version": "0.1.0",
    }


@app.post("/api/summarize", response_model=SummarizeResponse)
async def summarize_text(request: SummarizeRequest) -> SummarizeResponse:
    """Generate summary notes from PDF text using OpenRouter.

    Args:
        request: SummarizeRequest with text and optional context

    Returns:
        SummarizeResponse with generated summary or error
    """
    if not client:
        logger.error("OpenRouter client not initialized")
        raise HTTPException(status_code=500, detail="AI service not available")

    try:
        # Build the prompt with context
        user_prompt = build_summarize_prompt(
            text=request.text,
            pdf_name=request.pdf_name,
            page_number=request.page_number,
        )

        logger.info(
            f"Processing summarization request - "
            f"PDF: {request.pdf_name or 'unknown'}, "
            f"Page: {request.page_number or 'unknown'}, "
            f"Text length: {len(request.text)} chars"
        )

        # Call OpenRouter API
        response = client.chat.completions.create(
            model=settings.model_name,
            messages=[
                {"role": "system", "content": SUMMARIZE_SYSTEM_PROMPT},
                {"role": "user", "content": user_prompt},
            ],
            max_tokens=settings.max_tokens,
            temperature=settings.temperature,
        )

        # Extract summary from response
        summary = response.choices[0].message.content

        if not summary:
            logger.warning("Empty response from AI model")
            return SummarizeResponse(
                summary=None,
                success=False,
                error="AI model returned empty response",
            )

        logger.info(f"Successfully generated summary ({len(summary)} chars)")

        return SummarizeResponse(
            summary=summary.strip(),
            success=True,
            error=None,
        )

    except Exception as e:
        logger.error(f"Error during summarization: {str(e)}", exc_info=True)
        return SummarizeResponse(
            summary=None,
            success=False,
            error=f"Summarization failed: {str(e)}",
        )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host=settings.host,
        port=settings.port,
        reload=True,
        log_level=settings.log_level,
    )
