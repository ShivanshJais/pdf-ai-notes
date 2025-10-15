-- SQLite database module for PDF note-taking
-- Uses Hammerspoon's built-in hs.sqlite3 module

local db = {}

-- Database connection
local dbConn = nil

-- Database file path
db.DB_PATH = hs.configdir .. "/pdf-ai-notes/db/notes.db"

-- Initialize database connection
function db.connect()
    if dbConn then
        return dbConn
    end

    -- Ensure directory exists
    local dbDir = db.DB_PATH:match("(.*/)")
    hs.execute("mkdir -p '" .. dbDir .. "'")

    dbConn = hs.sqlite3.open(db.DB_PATH)

    if not dbConn then
        print("ERROR: Failed to open database at: " .. db.DB_PATH)
        return nil
    end

    print("Database connected: " .. db.DB_PATH)
    return dbConn
end

-- Close database connection
function db.close()
    if dbConn then
        dbConn:close()
        dbConn = nil
        print("Database closed")
    end
end

-- Initialize database with schema
function db.init()
    local conn = db.connect()
    if not conn then
        return false
    end

    print("Initializing database schema...")

    local schema = [[
        -- Track PDFs with file metadata
        CREATE TABLE IF NOT EXISTS pdfs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_path TEXT UNIQUE NOT NULL,
            file_name TEXT NOT NULL,
            file_size INTEGER,
            file_modified_at INTEGER,
            first_seen_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            last_read_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        -- Track pages and view counts
        CREATE TABLE IF NOT EXISTS pages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            pdf_id INTEGER NOT NULL,
            page_number INTEGER NOT NULL,
            last_viewed_at DATETIME,
            view_count INTEGER DEFAULT 0,
            FOREIGN KEY (pdf_id) REFERENCES pdfs(id),
            UNIQUE(pdf_id, page_number)
        );

        -- AI-generated notes
        CREATE TABLE IF NOT EXISTS notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            page_id INTEGER NOT NULL,
            note_content TEXT,
            note_type TEXT,
            directive_name TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (page_id) REFERENCES pages(id)
        );

        -- Extracted concepts
        CREATE TABLE IF NOT EXISTS concepts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            description TEXT
        );

        -- Link concepts to pages
        CREATE TABLE IF NOT EXISTS page_concepts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            page_id INTEGER NOT NULL,
            concept_id INTEGER NOT NULL,
            context TEXT,
            FOREIGN KEY (page_id) REFERENCES pages(id),
            FOREIGN KEY (concept_id) REFERENCES concepts(id),
            UNIQUE(page_id, concept_id)
        );

        -- User directives for note generation
        CREATE TABLE IF NOT EXISTS directives (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            prompt_template TEXT NOT NULL,
            is_default BOOLEAN DEFAULT 0
        );

        -- Indexes for performance
        CREATE INDEX IF NOT EXISTS idx_pdf_path ON pdfs(file_path);
        CREATE INDEX IF NOT EXISTS idx_page_pdf_number ON pages(pdf_id, page_number);
        CREATE INDEX IF NOT EXISTS idx_concept_name ON concepts(name);
    ]]

    local result = conn:exec(schema)

    if result == hs.sqlite3.OK then
        print("Database schema initialized successfully")

        -- Insert default directive if not exists
        local defaultDirective = [[
            INSERT OR IGNORE INTO directives (name, prompt_template, is_default)
            VALUES ('summary', 'Generate concise notes summarizing the key points from this text.', 1);
        ]]
        conn:exec(defaultDirective)

        return true
    else
        print("ERROR: Database initialization failed: " .. conn:errmsg())
        return false
    end
end

-- Get or create PDF record with metadata
function db.getOrCreatePDF(filePath, fileName, fileSize, fileModifiedAt)
    local conn = db.connect()
    if not conn then return nil end

    -- Try to get existing PDF
    local stmt = conn:prepare("SELECT id, file_size, file_modified_at FROM pdfs WHERE file_path = ?")
    if not stmt then
        print("ERROR: Failed to prepare statement: " .. conn:errmsg())
        return nil
    end

    stmt:bind_values(filePath)

    local pdfId = nil
    local existingSize = nil
    local existingMtime = nil

    for row in stmt:nrows() do
        pdfId = row.id
        existingSize = row.file_size
        existingMtime = row.file_modified_at
        break
    end
    stmt:finalize()

    if pdfId then
        -- Update last_read_at and metadata if changed
        local updateStmt = conn:prepare([[
            UPDATE pdfs
            SET last_read_at = CURRENT_TIMESTAMP,
                file_size = ?,
                file_modified_at = ?
            WHERE id = ?
        ]])
        if updateStmt then
            updateStmt:bind_values(fileSize, fileModifiedAt, pdfId)
            updateStmt:step()
            updateStmt:finalize()
        end

        -- Check if file changed
        if existingSize ~= fileSize or existingMtime ~= fileModifiedAt then
            print("PDF metadata changed - file may have been updated")
        end

        return pdfId
    end

    -- Create new PDF record
    local insertStmt = conn:prepare([[
        INSERT INTO pdfs (file_path, file_name, file_size, file_modified_at)
        VALUES (?, ?, ?, ?)
    ]])
    if not insertStmt then
        print("ERROR: Failed to prepare insert: " .. conn:errmsg())
        return nil
    end

    insertStmt:bind_values(filePath, fileName, fileSize, fileModifiedAt)
    insertStmt:step()
    insertStmt:finalize()

    local newId = conn:last_insert_rowid()
    print("New PDF registered: " .. fileName .. " (ID: " .. newId .. ")")
    return newId
end

-- Record a page view
function db.recordPageView(pdfId, pageNumber)
    if not pdfId or not pageNumber then
        return false
    end

    local conn = db.connect()
    if not conn then return false end

    local sql = [[
        INSERT INTO pages (pdf_id, page_number, last_viewed_at, view_count)
        VALUES (?, ?, CURRENT_TIMESTAMP, 1)
        ON CONFLICT(pdf_id, page_number)
        DO UPDATE SET
            last_viewed_at = CURRENT_TIMESTAMP,
            view_count = view_count + 1
    ]]

    local stmt = conn:prepare(sql)
    if not stmt then
        print("ERROR: Failed to prepare recordPageView: " .. conn:errmsg())
        return false
    end

    stmt:bind_values(pdfId, pageNumber)
    local result = stmt:step()
    stmt:finalize()

    return result == hs.sqlite3.DONE
end

-- Get page ID (needed for storing notes)
function db.getPageId(pdfId, pageNumber)
    local conn = db.connect()
    if not conn then return nil end

    local stmt = conn:prepare("SELECT id FROM pages WHERE pdf_id = ? AND page_number = ?")
    if not stmt then return nil end

    stmt:bind_values(pdfId, pageNumber)

    local pageId = nil
    for row in stmt:nrows() do
        pageId = row.id
        break
    end
    stmt:finalize()

    return pageId
end

-- Store a note for a page
function db.storeNote(pageId, noteContent, noteType, directiveName)
    if not pageId or not noteContent then
        return false
    end

    local conn = db.connect()
    if not conn then return false end

    local stmt = conn:prepare([[
        INSERT INTO notes (page_id, note_content, note_type, directive_name)
        VALUES (?, ?, ?, ?)
    ]])
    if not stmt then
        print("ERROR: Failed to prepare storeNote: " .. conn:errmsg())
        return false
    end

    stmt:bind_values(pageId, noteContent, noteType or "summary", directiveName or "default")
    local result = stmt:step()
    stmt:finalize()

    return result == hs.sqlite3.DONE
end

-- Get notes for a page
function db.getPageNotes(pageId)
    local conn = db.connect()
    if not conn then return {} end

    local stmt = conn:prepare([[
        SELECT note_content, note_type, directive_name, created_at
        FROM notes
        WHERE page_id = ?
        ORDER BY created_at DESC
    ]])
    if not stmt then return {} end

    stmt:bind_values(pageId)

    local notes = {}
    for row in stmt:nrows() do
        table.insert(notes, {
            content = row.note_content,
            type = row.note_type,
            directive = row.directive_name,
            created_at = row.created_at
        })
    end
    stmt:finalize()

    return notes
end

-- Get statistics for debugging
function db.getStats()
    local conn = db.connect()
    if not conn then return nil end

    local sql = [[
        SELECT
            (SELECT COUNT(*) FROM pdfs) as total_pdfs,
            (SELECT COUNT(*) FROM pages) as total_pages,
            (SELECT SUM(view_count) FROM pages) as total_views,
            (SELECT COUNT(*) FROM notes) as total_notes,
            (SELECT COUNT(*) FROM concepts) as total_concepts
    ]]

    local stmt = conn:prepare(sql)
    if not stmt then return nil end

    local stats = nil
    for row in stmt:nrows() do
        stats = row
        break
    end
    stmt:finalize()

    return stats
end

return db
