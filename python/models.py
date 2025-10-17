"""Pydantic models for request/response validation."""

from typing import Optional
from pydantic import BaseModel, Field


class SummarizeRequest(BaseModel):
    """Request model for text summarization endpoint."""

    text: str = Field(
        ...,
        description="Extracted text from PDF page to summarize",
        min_length=1,
    )
    pdf_name: Optional[str] = Field(
        None,
        description="Name of the PDF file (for context)",
    )
    page_number: Optional[int] = Field(
        None,
        description="Page number in the PDF (for context)",
        ge=1,
    )

    model_config = {
        "json_schema_extra": {
            "example": {
                "text": "Neural networks are...",
                "pdf_name": "deep_learning.pdf",
                "page_number": 42,
            }
        }
    }


class SummarizeResponse(BaseModel):
    """Response model for text summarization endpoint."""

    summary: Optional[str] = Field(
        None,
        description="Generated summary in markdown format",
    )
    success: bool = Field(
        ...,
        description="Whether the summarization was successful",
    )
    error: Optional[str] = Field(
        None,
        description="Error message if summarization failed",
    )

    model_config = {
        "json_schema_extra": {
            "example": {
                "summary": "## Key Concepts\n\n- Neural networks...",
                "success": True,
                "error": None,
            }
        }
    }