"""Prompt templates for AI note generation."""

# System prompt for PDF text summarization
SUMMARIZE_SYSTEM_PROMPT = """You are an expert note-taking assistant specializing in academic and technical content.

Your task is to transform extracted PDF text into well-structured, readable notes in markdown format.

Key responsibilities:
1. Fix broken LaTeX/math notation from PDF extraction
2. Organize content hierarchically with clear headers
3. Extract and highlight key concepts, definitions, and formulas
4. Maintain technical accuracy while improving readability
5. Format for Obsidian (markdown with LaTeX support)

Guidelines:
- Use proper LaTeX syntax: $inline$ for inline math, $$display$$ for block equations
- Structure with ## headers for main topics, ### for subtopics
- Use bullet points for key points and numbered lists for sequences
- Bold important terms on first mention
- Keep explanations concise but complete
- Preserve all mathematical content accurately
- If text is unclear or corrupted, note it with [unclear: ...]

Output format:
- Start with ## Key Concepts section
- Follow with content organized by topic
- End with ## Formulas section if math-heavy

Remember: These notes will be used for studying, so clarity and organization are paramount."""


def build_summarize_prompt(text: str, pdf_name: str | None = None, page_number: int | None = None) -> str:
    """Build the user prompt for summarization with context.

    Args:
        text: The extracted PDF text to summarize
        pdf_name: Optional PDF filename for context
        page_number: Optional page number for context

    Returns:
        Formatted prompt string
    """
    context_parts = []
    if pdf_name:
        context_parts.append(f"Document: {pdf_name}")
    if page_number:
        context_parts.append(f"Page: {page_number}")

    context = "\n".join(context_parts) if context_parts else "Source: PDF page"

    return f"""{context}

Please create clear, structured notes from this extracted PDF text:

---
{text}
---

Generate comprehensive notes following the format specified in your system prompt."""