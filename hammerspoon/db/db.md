# PDF AI Notes - Database Documentation

## Overview

This database tracks PDF reading activity, stores AI-generated notes, and builds a knowledge graph of concepts across documents.

**Location:** `~/.hammerspoon/pdf-ai-notes/db/notes.db`
**Type:** SQLite3
**Access:** Via `modules/database.lua` using lsqlite3

---

## Schema

### Tables

#### 1. `pdfs`
Tracks PDF documents with file metadata for change detection.

| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PK | Unique PDF identifier |
| file_path | TEXT UNIQUE | Absolute path to PDF file |
| file_name | TEXT | Filename only (e.g., "ml_book.pdf") |
| file_size | INTEGER | File size in bytes |
| file_modified_at | INTEGER | Unix timestamp of last modification |
| first_seen_at | DATETIME | When first tracked |
| last_read_at | DATETIME | Last time any page was viewed |

**Indexes:** `idx_pdf_path` on `file_path`

#### 2. `pages`
Tracks individual pages and view counts.

| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PK | Unique page identifier |
| pdf_id | INTEGER FK | References pdfs(id) |
| page_number | INTEGER | Page number (1-indexed) |
| last_viewed_at | DATETIME | Last view timestamp |
| view_count | INTEGER | Total number of views |

**Constraints:** UNIQUE(pdf_id, page_number)
**Indexes:** `idx_page_pdf_number` on `(pdf_id, page_number)`

#### 3. `notes`
AI-generated notes for pages.

| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PK | Unique note identifier |
| page_id | INTEGER FK | References pages(id) |
| note_content | TEXT | Markdown-formatted note content |
| note_type | TEXT | Type: 'summary', 'detailed', 'math-cleanup', etc. |
| directive_name | TEXT | Which directive was used |
| created_at | DATETIME | When note was generated |

**Multiple notes per page allowed** (different types/directives)

#### 4. `concepts`
Extracted key concepts for knowledge graph.

| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PK | Unique concept identifier |
| name | TEXT UNIQUE | Concept name (e.g., "neural networks") |
| description | TEXT | AI-generated explanation |

**Indexes:** `idx_concept_name` on `name`

#### 5. `page_concepts`
Many-to-many relationship between pages and concepts.

| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PK | Unique link identifier |
| page_id | INTEGER FK | References pages(id) |
| concept_id | INTEGER FK | References concepts(id) |
| context | TEXT | Text snippet where concept appears |

**Constraints:** UNIQUE(page_id, concept_id)

#### 6. `directives`
User-defined prompts for note generation.

| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PK | Unique directive identifier |
| name | TEXT UNIQUE | Directive name (e.g., "summary") |
| prompt_template | TEXT | The actual prompt sent to AI |
| is_default | BOOLEAN | Whether this is the default directive |

---

## Design Decisions

### 1. **No Text Storage in Database**

**Decision:** Pages table does NOT store extracted text content.

**Rationale:**
- PDF text is extracted on-the-fly from source files
- Avoids database bloat (text can be 10-100KB per page)
- Always fresh (no stale cached text)
- Simpler implementation

**Trade-offs:**
- Can't search text without re-extracting
- Slower if PDF is moved/deleted
- Acceptable for MVP use case

### 2. **Metadata-Based Change Detection**

**Decision:** Use file size + modification time (mtime) instead of file hashing.

**Rationale:**
- **Fast:** No need to read entire file
- **Sufficient:** PDFs are rarely edited in-place
- **Simple:** Built into filesystem

**How it works:**
```lua
local metadata = utils.getFileMetadata(pdfPath)
-- {size = 1234567, modified_at = 1697234567}

pdfId = db.getOrCreatePDF(path, name, metadata.size, metadata.modified_at)
-- Automatically detects if size or mtime changed
```

**When this fails:**
- Copying files may reset mtime
- Some editors don't update mtime properly
- For those cases, could add page-level text hashing later

### 3. **Raw Text Storage (No LaTeX Conversion)**

**Decision:** Store extracted text as-is, including broken LaTeX.

**Example:**
```
V=

0.0, E = 0,M = 0
2−14 ×M
32 , E = 0,M ̸= 0
```

**Rationale:**
- PDF extraction loses structure (superscripts, fractions)
- Attempting to fix in Lua is error-prone
- **AI handles cleanup** when generating notes
- No data loss

**Workflow:**
1. Extract raw text (with broken math)
2. Sanitize (remove control chars only)
3. Store as-is
4. AI formats to proper LaTeX in notes
5. Obsidian renders beautifully

### 4. **Minimal Sanitization**

**What we remove:**
- Null bytes (`\0`)
- Control characters (except `\n`, `\t`)
- Excessive whitespace (>2 consecutive newlines)

**What we preserve:**
- LaTeX commands (`\theta`, `\frac{}{}`)
- Unicode math symbols (`α`, `β`, `∑`)
- Structure (indentation for equations)
- Special characters

**Why minimal:**
- Obsidian supports LaTeX natively
- AI is smart enough to handle edge cases
- Better to preserve data than risk corruption

---

## Common Queries

### Get all PDFs with reading activity
```lua
local stats = db.getStats()
print("Total PDFs:", stats.total_pdfs)
print("Total pages viewed:", stats.total_pages)
print("Total views:", stats.total_views)
```

### Get notes for a specific page
```lua
local pageId = db.getPageId(pdfId, 42)
local notes = db.getPageNotes(pageId)

for _, note in ipairs(notes) do
    print("Type:", note.type)
    print("Content:", note.content)
end
```

### Check if PDF was modified
```lua
-- Happens automatically in db.getOrCreatePDF()
-- Logs: "PDF metadata changed - file may have been updated"
```

### Record a page view
```lua
-- Happens automatically in poller.onPageChange()
db.recordPageView(pdfId, pageNumber)
```

---

## Future Enhancements

### Full-Text Search
```sql
CREATE VIRTUAL TABLE pages_fts USING fts5(
    page_id UNINDEXED,
    text_content
);
```

### Flashcards
```sql
CREATE TABLE flashcards (
    id INTEGER PRIMARY KEY,
    page_id INTEGER NOT NULL,
    question TEXT,
    answer TEXT,
    next_review_date DATE,
    FOREIGN KEY (page_id) REFERENCES pages(id)
);
```

### Reading Sessions (Analytics)
```sql
CREATE TABLE reading_sessions (
    id INTEGER PRIMARY KEY,
    pdf_id INTEGER NOT NULL,
    page_number INTEGER,
    started_at DATETIME,
    duration_seconds INTEGER,
    FOREIGN KEY (pdf_id) REFERENCES pdfs(id)
);
```

### Page-Level Text Hashing
```sql
ALTER TABLE pages ADD COLUMN text_hash TEXT;
-- For detecting changes at page level
```

---

## Python Integration

### Sending Data to Server
```lua
local payload = {
    pdf_name = fileName,
    pdf_path = pdfPath,
    page_number = pageNumber,
    text = sanitizedText,  -- Already cleaned
    directive = "summary"
}

-- Send via HTTP POST (implementation pending)
```

### Receiving Notes from Server
```python
# Python returns:
{
    "notes": "**Key Concepts**\n- Neural networks...",
    "note_type": "summary",
    "concepts": ["neural networks", "backpropagation"]
}
```

```lua
-- Store in database
local pageId = db.getPageId(pdfId, pageNumber)
db.storeNote(pageId, response.notes, response.note_type, "summary")

-- Store concepts (future implementation)
for _, concept in ipairs(response.concepts) do
    -- Link concept to page
end
```

---

## Maintenance

### Backup Database
```bash
cp ~/.hammerspoon/pdf-ai-notes/db/notes.db ~/backups/notes-$(date +%Y%m%d).db
```

### View Database Contents
```bash
sqlite3 ~/.hammerspoon/pdf-ai-notes/db/notes.db

# Example queries:
SELECT * FROM pdfs;
SELECT pdf_id, page_number, view_count FROM pages ORDER BY view_count DESC LIMIT 10;
SELECT COUNT(*) FROM notes;
```

### Reset Database
```bash
rm ~/.hammerspoon/pdf-ai-notes/db/notes.db
# Will be recreated on next Hammerspoon reload
```

---

## Implementation Notes

- All database access uses **prepared statements** for SQL injection safety
- Connection is **persistent** (opened once, reused)
- **No transactions** in MVP (single-threaded Lua)
- Schema creation is **idempotent** (safe to run multiple times)
- Default directive ("summary") is auto-inserted on init

---

**Last Updated:** October 2025
**Schema Version:** 1.0 (MVP)
