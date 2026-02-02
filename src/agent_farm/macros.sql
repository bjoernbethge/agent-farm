-- macros.sql

-- Mock get_secret for now if not native:
CREATE OR REPLACE MACRO get_secret(name) AS 'mock_secret_value';

-- =============================================================================
-- OLLAMA BASE
-- =============================================================================

-- Base Ollama API endpoint
CREATE OR REPLACE MACRO ollama_base() AS 'http://localhost:11434';

-- Generic Ollama chat completion (simple)
CREATE OR REPLACE MACRO ollama_chat(model_name, prompt) AS (
    SELECT json_extract_string(
        http_post(
            ollama_base() || '/api/generate',
            headers := MAP {'Content-Type': 'application/json'},
            body := json_object(
                'model', model_name,
                'prompt', prompt,
                'stream', false
            )
        ).body,
        '$.response'
    )
);

-- Ollama chat with messages format (for tool calling)
CREATE OR REPLACE MACRO ollama_chat_messages(model_name, messages_json) AS (
    SELECT http_post(
        ollama_base() || '/api/chat',
        headers := MAP {'Content-Type': 'application/json'},
        body := json_object(
            'model', model_name,
            'messages', json(messages_json),
            'stream', false
        )
    ).body
);

-- Ollama chat WITH tools (function calling)
CREATE OR REPLACE MACRO ollama_chat_with_tools(model_name, messages_json, tools_json) AS (
    SELECT http_post(
        ollama_base() || '/api/chat',
        headers := MAP {'Content-Type': 'application/json'},
        body := json_object(
            'model', model_name,
            'messages', json(messages_json),
            'tools', json(tools_json),
            'stream', false
        )
    ).body
);

-- Extract tool calls from Ollama response
CREATE OR REPLACE MACRO extract_tool_calls(response_body) AS (
    SELECT json_extract(response_body, '$.message.tool_calls')
);

-- Extract text response from Ollama response
CREATE OR REPLACE MACRO extract_response(response_body) AS (
    SELECT json_extract_string(response_body, '$.message.content')
);

-- Ollama embeddings
CREATE OR REPLACE MACRO ollama_embed(model_name, text_input) AS (
    SELECT json_extract(
        http_post(
            ollama_base() || '/api/embeddings',
            headers := MAP {'Content-Type': 'application/json'},
            body := json_object(
                'model', model_name,
                'prompt', text_input
            )
        ).body,
        '$.embedding'
    )::FLOAT[]
);

-- =============================================================================
-- CLOUD MODELLE (via Ollama Gateway)
-- =============================================================================

-- DeepSeek V3.1 (671B Cloud)
CREATE OR REPLACE MACRO deepseek(prompt) AS ollama_chat('deepseek-v3.1:671b-cloud', prompt);

-- Kimi K2 (1T Cloud, mit Thinking-Variante)
CREATE OR REPLACE MACRO kimi(prompt) AS ollama_chat('kimi-k2:1t-cloud', prompt);
CREATE OR REPLACE MACRO kimi_think(prompt) AS ollama_chat('kimi-k2-thinking:cloud', prompt);

-- Gemini 3 Pro (Cloud)
CREATE OR REPLACE MACRO gemini(prompt) AS ollama_chat('gemini-3-pro-preview:latest', prompt);

-- Qwen3 Coder 480B (Cloud)
CREATE OR REPLACE MACRO qwen3_coder(prompt) AS ollama_chat('qwen3-coder:480b-cloud', prompt);

-- Qwen3 VL 235B (Vision, Cloud)
CREATE OR REPLACE MACRO qwen3_vl(prompt) AS ollama_chat('qwen3-vl:235b-cloud', prompt);

-- GLM 4.6 (Cloud)
CREATE OR REPLACE MACRO glm(prompt) AS ollama_chat('glm-4.6:cloud', prompt);

-- MiniMax M2 (Cloud)
CREATE OR REPLACE MACRO minimax(prompt) AS ollama_chat('minimax-m2:cloud', prompt);

-- GPT-OSS (Cloud, 120B und 20B)
CREATE OR REPLACE MACRO gpt_oss(prompt) AS ollama_chat('gpt-oss:120b-cloud', prompt);
CREATE OR REPLACE MACRO gpt_oss_small(prompt) AS ollama_chat('gpt-oss:20b-cloud', prompt);

-- =============================================================================
-- CLOUD MODELLE MIT TOOL CALLING
-- =============================================================================

-- DeepSeek with tools
CREATE OR REPLACE MACRO deepseek_tools(prompt, tools_json) AS (
    SELECT ollama_chat_with_tools(
        'deepseek-v3.1:671b-cloud',
        json_array(json_object('role', 'user', 'content', prompt)),
        tools_json
    )
);

-- Kimi with tools
CREATE OR REPLACE MACRO kimi_tools(prompt, tools_json) AS (
    SELECT ollama_chat_with_tools(
        'kimi-k2:1t-cloud',
        json_array(json_object('role', 'user', 'content', prompt)),
        tools_json
    )
);

-- Gemini with tools
CREATE OR REPLACE MACRO gemini_tools(prompt, tools_json) AS (
    SELECT ollama_chat_with_tools(
        'gemini-3-pro-preview:latest',
        json_array(json_object('role', 'user', 'content', prompt)),
        tools_json
    )
);

-- Qwen3 Coder with tools
CREATE OR REPLACE MACRO qwen3_coder_tools(prompt, tools_json) AS (
    SELECT ollama_chat_with_tools(
        'qwen3-coder:480b-cloud',
        json_array(json_object('role', 'user', 'content', prompt)),
        tools_json
    )
);

-- =============================================================================
-- MCP TOOL HELPERS
-- =============================================================================

-- Convert MCP tool schema to Ollama tool format
-- Usage: SELECT mcp_to_ollama_tool('tool_name', 'description', '{"type":"object","properties":{...}}')
CREATE OR REPLACE MACRO mcp_to_ollama_tool(tool_name, description, input_schema_json) AS (
    SELECT json_object(
        'type', 'function',
        'function', json_object(
            'name', tool_name,
            'description', description,
            'parameters', json(input_schema_json)
        )
    )
);

-- Build tools array from multiple tool definitions
CREATE OR REPLACE MACRO build_tools_array(tools_list) AS (
    SELECT json_group_array(json(tool)) FROM (SELECT unnest(tools_list) as tool)
);

-- =============================================================================
-- RAG HELPERS
-- =============================================================================

-- Standard RAG mit DeepSeek (beste Qualität)
CREATE OR REPLACE MACRO rag_query(question, context) AS
    deepseek('Beantworte basierend auf folgendem Kontext:\n\n' || context || '\n\nFrage: ' || question);

-- RAG mit Kimi Thinking (für komplexe Reasoning-Aufgaben)
CREATE OR REPLACE MACRO rag_think(question, context) AS
    kimi_think('Analysiere sorgfältig den Kontext und beantworte die Frage:\n\nKontext:\n' || context || '\n\nFrage: ' || question);

-- =============================================================================
-- AGENTIC HELPERS
-- =============================================================================

-- Agent loop: Send prompt with tools, get response
-- Returns full response including potential tool_calls
CREATE OR REPLACE MACRO agent_call(model_name, system_prompt, user_prompt, tools_json) AS (
    SELECT ollama_chat_with_tools(
        model_name,
        json_array(
            json_object('role', 'system', 'content', system_prompt),
            json_object('role', 'user', 'content', user_prompt)
        ),
        tools_json
    )
);

-- Check if response contains tool calls
CREATE OR REPLACE MACRO has_tool_calls(response_body) AS (
    SELECT json_extract(response_body, '$.message.tool_calls') IS NOT NULL
        AND json_array_length(json_extract(response_body, '$.message.tool_calls')) > 0
);

-- =============================================================================
-- EXTERNAL APIS
-- =============================================================================

CREATE OR REPLACE MACRO elevenlabs_tts(text_input) AS TABLE
SELECT
    http_post(
        'https://api.elevenlabs.io/v1/tts/voice_id',
        headers := MAP {'xi-api-key': get_secret('elevenlabs_key')},
        body := json_object('text', text_input)
    ) AS audio_file_bytes;

-- =============================================================================
-- UTILITY MACROS (must be defined before use)
-- =============================================================================

-- URL encode helper
CREATE OR REPLACE MACRO url_encode(str) AS (
    replace(replace(replace(replace(replace(replace(
        str,
        '%', '%25'),
        ' ', '%20'),
        '&', '%26'),
        '=', '%3D'),
        '?', '%3F'),
        '#', '%23')
);

-- Timestamp helpers
CREATE OR REPLACE MACRO now_iso() AS (
    strftime(now(), '%Y-%m-%dT%H:%M:%SZ')
);

CREATE OR REPLACE MACRO now_unix() AS (
    epoch(now())
);

-- =============================================================================
-- WEB SEARCH
-- =============================================================================

-- DuckDuckGo Instant Answer API (kostenlos, kein API Key)
-- HINWEIS: Das ist KEIN vollstaendiger Suchergebnis-API, nur Instant Answers!
CREATE OR REPLACE MACRO ddg_instant(query) AS (
    http_get(
        'https://api.duckduckgo.com/?q=' || url_encode(query) || '&format=json&no_html=1'
    ).body::JSON
);

-- Extrahiere Abstract aus DuckDuckGo Response
CREATE OR REPLACE MACRO ddg_abstract(query) AS (
    json_extract_string(ddg_instant(query), '$.Abstract')
);

-- Extrahiere Related Topics aus DuckDuckGo
CREATE OR REPLACE MACRO ddg_related(query) AS (
    json_extract(ddg_instant(query), '$.RelatedTopics')
);

-- DuckDuckGo Definition
CREATE OR REPLACE MACRO ddg_definition(query) AS (
    json_extract_string(ddg_instant(query), '$.Definition')
);

-- Brave Search API (2000 queries/Monat kostenlos)
-- Benoetigt API Key in get_secret('brave_api_key')
CREATE OR REPLACE MACRO brave_search(query) AS (
    http_get(
        'https://api.search.brave.com/res/v1/web/search?q=' || url_encode(query),
        headers := MAP {'X-Subscription-Token': get_secret('brave_api_key')}
    ).body::JSON
);

-- Brave Search - nur Web Results
CREATE OR REPLACE MACRO brave_results(query) AS (
    json_extract(brave_search(query), '$.web.results')
);

-- Brave News
CREATE OR REPLACE MACRO brave_news(query) AS (
    http_get(
        'https://api.search.brave.com/res/v1/news/search?q=' || url_encode(query),
        headers := MAP {'X-Subscription-Token': get_secret('brave_api_key')}
    ).body::JSON
);

-- =============================================================================
-- SHELL / COMMAND EXECUTION (via shellfs)
-- Syntax: Pipe-Zeichen am Ende '|' = lese von diesem Befehl
-- =============================================================================

-- Shell-Befehl ausfuehren und Output als Text
CREATE OR REPLACE MACRO shell(cmd) AS (
    (SELECT content FROM read_text(cmd || ' |'))
);

-- Shell als CSV Tabelle
CREATE OR REPLACE MACRO shell_csv(cmd) AS TABLE
    SELECT * FROM read_csv(cmd || ' |', auto_detect=true);

-- Shell als JSON Tabelle
CREATE OR REPLACE MACRO shell_json(cmd) AS TABLE
    SELECT * FROM read_json(cmd || ' |', auto_detect=true);

-- Windows cmd.exe
CREATE OR REPLACE MACRO cmd(command) AS (
    (SELECT content FROM read_text('cmd /c ' || command || ' |'))
);

-- PowerShell
CREATE OR REPLACE MACRO pwsh(command) AS (
    (SELECT content FROM read_text('pwsh -NoProfile -Command "' || replace(command, '"', '`"') || '" |'))
);

-- =============================================================================
-- PYTHON / UV EXECUTION
-- =============================================================================

-- Python Code via uv run (inline)
CREATE OR REPLACE MACRO py(code) AS (
    (SELECT content FROM read_text('uv run python -c "' || replace(code, '"', chr(92) || '"') || '" |'))
);

-- Python mit Dependencies (uv run --with)
CREATE OR REPLACE MACRO py_with(deps, code) AS (
    (SELECT content FROM read_text('uv run --with ' || deps || ' python -c "' || replace(code, '"', chr(92) || '"') || '" |'))
);

-- Python Script ausfuehren
CREATE OR REPLACE MACRO py_script(script_path) AS (
    (SELECT content FROM read_text('uv run python ' || script_path || ' |'))
);

-- Python Script mit Args
CREATE OR REPLACE MACRO py_script_args(script_path, args) AS (
    (SELECT content FROM read_text('uv run python ' || script_path || ' ' || args || ' |'))
);

-- Python Expression evaluieren (print automatisch)
CREATE OR REPLACE MACRO py_eval(expr) AS (
    (SELECT content FROM read_text('uv run python -c "print(' || replace(expr, '"', chr(92) || '"') || ')" |'))
);

-- =============================================================================
-- WEB SCRAPING / FETCH
-- =============================================================================

-- Fetch URL und gib rohen Content zurueck
CREATE OR REPLACE MACRO fetch(url) AS (
    http_get(url).body
);

-- Fetch URL und konvertiere HTML zu plain text (benoetigt htmlstringify)
CREATE OR REPLACE MACRO fetch_text(url) AS (
    htmlstringify(http_get(url).body)
);

-- Fetch JSON API
CREATE OR REPLACE MACRO fetch_json(url) AS (
    http_get(url).body::JSON
);

-- Fetch mit Custom Headers
CREATE OR REPLACE MACRO fetch_headers(url, headers_map) AS (
    http_get(url, headers := headers_map).body
);

-- Fetch mit User-Agent (fuer Sites die Bots blocken)
CREATE OR REPLACE MACRO fetch_ua(url) AS (
    http_get(url, headers := MAP {'User-Agent': 'Mozilla/5.0 AppleWebKit/537.36'}).body
);

-- POST Request mit JSON Body
CREATE OR REPLACE MACRO post_json(url, body_json) AS (
    http_post(
        url,
        headers := MAP {'Content-Type': 'application/json'},
        body := body_json
    ).body::JSON
);

-- POST mit Form Data
CREATE OR REPLACE MACRO post_form(url, form_data) AS (
    http_post(
        url,
        headers := MAP {'Content-Type': 'application/x-www-form-urlencoded'},
        body := form_data
    ).body
);

-- =============================================================================
-- FILE OPERATIONS
-- =============================================================================

-- Lese Datei (native DuckDB)
CREATE OR REPLACE MACRO read_file(path) AS (
    (SELECT content FROM read_text(path))
);

-- Liste Verzeichnis (Unix)
CREATE OR REPLACE MACRO ls(path) AS (
    (SELECT content FROM read_text('ls -la ' || path || ' |'))
);

-- Liste Verzeichnis (Windows)
CREATE OR REPLACE MACRO dir_list(path) AS (
    (SELECT content FROM read_text('dir "' || path || '" |'))
);

-- Find files (Unix)
CREATE OR REPLACE MACRO find_files(path, pattern) AS (
    (SELECT content FROM read_text('find ' || path || ' -name "' || pattern || '" |'))
);

-- Find files (Windows)
CREATE OR REPLACE MACRO find_win(path, pattern) AS (
    (SELECT content FROM read_text('dir /s /b "' || path || chr(92) || pattern || '" |'))
);

-- Cat multiple files
CREATE OR REPLACE MACRO cat_files(pattern) AS TABLE
    SELECT * FROM read_text(pattern);

-- =============================================================================
-- GIT OPERATIONS
-- =============================================================================

CREATE OR REPLACE MACRO git_status() AS (
    (SELECT content FROM read_text('git status |'))
);

CREATE OR REPLACE MACRO git_log(n) AS (
    (SELECT content FROM read_text('git log -' || n::VARCHAR || ' --oneline |'))
);

CREATE OR REPLACE MACRO git_diff() AS (
    (SELECT content FROM read_text('git diff |'))
);

CREATE OR REPLACE MACRO git_branch() AS (
    (SELECT content FROM read_text('git branch -a |'))
);

-- =============================================================================
-- SYSTEM INFO
-- =============================================================================

-- System info (cross-platform via Python)
CREATE OR REPLACE MACRO sys_info() AS (
    (SELECT content FROM read_text('uv run python -c "import platform,json;print(json.dumps(dict(system=platform.system(),release=platform.release(),machine=platform.machine(),python=platform.python_version())))" |'))
);

-- Environment variable (Unix)
CREATE OR REPLACE MACRO env_var(name) AS (
    (SELECT content FROM read_text('printenv ' || name || ' |'))
);

-- Current working directory (Unix)
CREATE OR REPLACE MACRO cwd() AS (
    (SELECT content FROM read_text('pwd |'))
);

-- Environment variable (Windows)
CREATE OR REPLACE MACRO env_var_win(name) AS (
    (SELECT content FROM read_text('cmd /c echo %' || name || '% |'))
);

-- Current working directory (Windows)
CREATE OR REPLACE MACRO cwd_win() AS (
    (SELECT content FROM read_text('cmd /c cd |'))
);

-- =============================================================================
-- KOMBINIERTE POWER-MAKROS
-- =============================================================================

-- Web Search + LLM Summary
CREATE OR REPLACE MACRO search_and_summarize(query) AS (
    deepseek(
        'Fasse die Suchergebnisse zusammen und beantworte: ' || query ||
        chr(10) || chr(10) || 'Suchergebnisse: ' || COALESCE(ddg_abstract(query), 'Keine Ergebnisse')
    )
);

-- Fetch Page + LLM Analysis
CREATE OR REPLACE MACRO analyze_page(url, question) AS (
    deepseek(
        'Analysiere den Webseiten-Inhalt und beantworte: ' || question ||
        chr(10) || chr(10) || 'Inhalt: ' || fetch_text(url)
    )
);

-- Code Review via LLM
CREATE OR REPLACE MACRO review_code(file_path) AS (
    deepseek(
        'Code Review - finde Bugs, Verbesserungen und Security Issues:' ||
        chr(10) || chr(10) || read_file(file_path)
    )
);

-- Explain Code
CREATE OR REPLACE MACRO explain_code(file_path) AS (
    deepseek('Erklaere diesen Code Schritt fuer Schritt:' || chr(10) || read_file(file_path))
);

-- Generate Python Code
CREATE OR REPLACE MACRO generate_py(task) AS (
    deepseek('Schreibe Python-Code fuer: ' || task || ' - Gib NUR Code zurueck, kein Markdown.')
);

-- =============================================================================
-- DATA PROCESSING HELPERS
-- =============================================================================

-- CSV von URL laden
CREATE OR REPLACE MACRO load_csv_url(url) AS TABLE
    SELECT * FROM read_csv(url, auto_detect=true);

-- JSON von URL laden
CREATE OR REPLACE MACRO load_json_url(url) AS TABLE
    SELECT * FROM read_json(url, auto_detect=true);

-- Parquet von URL laden
CREATE OR REPLACE MACRO load_parquet_url(url) AS TABLE
    SELECT * FROM read_parquet(url);

-- =============================================================================
-- VECTOR / EMBEDDING HELPERS (requires vss extension)
-- =============================================================================

-- Cosine similarity zwischen zwei Vektoren
CREATE OR REPLACE MACRO cosine_sim(vec1, vec2) AS (
    list_cosine_similarity(vec1, vec2)
);

-- Text zu Embedding (via Ollama)
CREATE OR REPLACE MACRO embed(text_input) AS (
    ollama_embed('nomic-embed-text', text_input)
);

-- Semantic search helper - gibt Similarity Score zurueck
CREATE OR REPLACE MACRO semantic_score(query_text, doc_text) AS (
    cosine_sim(embed(query_text), embed(doc_text))
);

-- =============================================================================
-- SECURE DESKTOP AGENT - POLICY & SECURITY MACROS
-- =============================================================================

-- Check if path is within allowed workspace
CREATE OR REPLACE MACRO path_in_workspace(check_path, workspace_path) AS (
    starts_with(check_path, workspace_path) OR
    starts_with(check_path, workspace_path || '/')
);

-- Check path against workspace table
CREATE OR REPLACE MACRO is_allowed_path(agent_id_param, check_path) AS (
    EXISTS (
        SELECT 1 FROM workspaces
        WHERE agent_id = agent_id_param
        AND path_in_workspace(check_path, path)
    )
);

-- Get workspace mode for a path
CREATE OR REPLACE MACRO get_workspace_mode(agent_id_param, check_path) AS (
    SELECT mode FROM workspaces
    WHERE agent_id = agent_id_param
    AND path_in_workspace(check_path, path)
    LIMIT 1
);

-- Check if shell is enabled for agent
CREATE OR REPLACE MACRO is_shell_enabled(agent_id_param) AS (
    SELECT COALESCE(shell_enabled, FALSE)
    FROM security_policy
    WHERE agent_id = agent_id_param
);

-- Check if command is in blocklist
CREATE OR REPLACE MACRO is_blocked_command(agent_id_param, cmd) AS (
    SELECT EXISTS (
        SELECT 1 FROM security_policy
        CROSS JOIN LATERAL unnest(shell_blocklist) AS t(blocked)
        WHERE agent_id = agent_id_param
        AND lower(cmd) LIKE '%' || lower(blocked) || '%'
    )
);

-- Check if file matches sensitive patterns
CREATE OR REPLACE MACRO is_sensitive_file(agent_id_param, file_path) AS (
    SELECT EXISTS (
        SELECT 1 FROM security_policy
        CROSS JOIN LATERAL unnest(sensitive_patterns) AS t(pattern)
        WHERE agent_id = agent_id_param
        AND glob(file_path, pattern)
    )
);

-- Check domain against allowed/blocked lists
CREATE OR REPLACE MACRO is_allowed_domain(agent_id_param, domain) AS (
    SELECT CASE
        WHEN EXISTS (
            SELECT 1 FROM security_policy
            CROSS JOIN LATERAL unnest(blocked_domains) AS t(blocked)
            WHERE agent_id = agent_id_param AND domain LIKE '%' || blocked
        ) THEN FALSE
        WHEN (SELECT allowed_domains FROM security_policy WHERE agent_id = agent_id_param) IS NULL THEN TRUE
        WHEN (SELECT len(allowed_domains) FROM security_policy WHERE agent_id = agent_id_param) = 0 THEN TRUE
        WHEN EXISTS (
            SELECT 1 FROM security_policy
            CROSS JOIN LATERAL unnest(allowed_domains) AS t(allowed)
            WHERE agent_id = agent_id_param AND domain LIKE '%' || allowed
        ) THEN TRUE
        ELSE FALSE
    END
);

-- =============================================================================
-- AUDIT LOGGING MACROS
-- =============================================================================

-- Log a tool call
CREATE OR REPLACE MACRO log_tool_call(session_id_param, tool_name_param, params_json, result_json, decision_param) AS (
    INSERT INTO audit_log (session_id, entry_type, tool_name, parameters, result, decision)
    VALUES (session_id_param, 'tool_call', tool_name_param, params_json::JSON, result_json::JSON, decision_param)
    RETURNING id
);

-- Log a policy violation
CREATE OR REPLACE MACRO log_violation(session_id_param, tool_name_param, violations_array) AS (
    INSERT INTO audit_log (session_id, entry_type, tool_name, decision, violations)
    VALUES (session_id_param, 'violation', tool_name_param, 'deny', violations_array)
    RETURNING id
);

-- Get recent audit entries
CREATE OR REPLACE MACRO recent_audit(session_id_param, limit_n) AS TABLE
    SELECT * FROM audit_log
    WHERE session_id = session_id_param
    ORDER BY timestamp DESC
    LIMIT limit_n;

-- =============================================================================
-- SECURE FILE OPERATIONS
-- =============================================================================

-- Secure file read - checks workspace first
CREATE OR REPLACE MACRO secure_read(agent_id_param, file_path) AS (
    CASE
        WHEN NOT is_allowed_path(agent_id_param, file_path)
            THEN json_object('error', 'Path not in allowed workspace', 'path', file_path)
        WHEN is_sensitive_file(agent_id_param, file_path)
            THEN json_object('error', 'Sensitive file - approval required', 'path', file_path)
        ELSE json_object('content', read_file(file_path), 'path', file_path)
    END
);

-- Secure directory listing
CREATE OR REPLACE MACRO secure_ls(agent_id_param, dir_path) AS (
    CASE
        WHEN NOT is_allowed_path(agent_id_param, dir_path)
            THEN json_object('error', 'Path not in allowed workspace', 'path', dir_path)
        ELSE json_object('listing', ls(dir_path), 'path', dir_path)
    END
);

-- Secure shell - checks policy and blocklist
CREATE OR REPLACE MACRO secure_shell(agent_id_param, cmd) AS (
    CASE
        WHEN NOT is_shell_enabled(agent_id_param)
            THEN json_object('error', 'Shell disabled for this security profile')
        WHEN is_blocked_command(agent_id_param, cmd)
            THEN json_object('error', 'Command blocked by security policy', 'cmd', cmd)
        ELSE json_object('output', shell(cmd), 'cmd', cmd)
    END
);

-- =============================================================================
-- AGENT CONFIG HELPERS
-- =============================================================================

-- Create new agent with default config
CREATE OR REPLACE MACRO create_agent(agent_id_param, agent_name, agent_role, sec_profile) AS (
    INSERT INTO agent_config (id, name, role, security_profile)
    VALUES (agent_id_param, agent_name, agent_role, sec_profile)
    RETURNING *
);

-- Add workspace to agent
CREATE OR REPLACE MACRO add_workspace(ws_id, agent_id_param, ws_path, ws_name, ws_mode) AS (
    INSERT INTO workspaces (id, agent_id, path, name, mode)
    VALUES (ws_id, agent_id_param, ws_path, ws_name, ws_mode)
    RETURNING *
);

-- Initialize security policy for agent
CREATE OR REPLACE MACRO init_security_policy(agent_id_param, shell_on, allowlist, blocklist) AS (
    INSERT INTO security_policy (agent_id, shell_enabled, shell_allowlist, shell_blocklist)
    VALUES (agent_id_param, shell_on, allowlist, blocklist)
    ON CONFLICT (agent_id) DO UPDATE SET
        shell_enabled = shell_on,
        shell_allowlist = allowlist,
        shell_blocklist = blocklist
    RETURNING *
);

-- Get agent config as JSON
CREATE OR REPLACE MACRO get_agent_config(agent_id_param) AS (
    SELECT json_object(
        'agent', (SELECT to_json(a) FROM agent_config a WHERE id = agent_id_param),
        'workspaces', (SELECT json_group_array(to_json(w)) FROM workspaces w WHERE agent_id = agent_id_param),
        'security', (SELECT to_json(s) FROM security_policy s WHERE agent_id = agent_id_param),
        'mcp_servers', (SELECT json_group_array(to_json(m)) FROM agent_mcp_servers m WHERE agent_id = agent_id_param)
    )
);

-- =============================================================================
-- SECURE AGENT LOOP
-- =============================================================================

-- Build system prompt with security rules
CREATE OR REPLACE MACRO agent_system_prompt(agent_id_param) AS (
    SELECT
        'You are ' || name || ', a ' || role || ' assistant.' || chr(10) ||
        'Security Profile: ' || security_profile || chr(10) ||
        'Allowed Workspaces: ' || (
            SELECT string_agg(path, ', ')
            FROM workspaces WHERE agent_id = agent_id_param
        ) || chr(10) ||
        CASE WHEN (SELECT shell_enabled FROM security_policy WHERE agent_id = agent_id_param)
            THEN 'Shell: ENABLED (use with caution)'
            ELSE 'Shell: DISABLED'
        END || chr(10) ||
        'Rules: Only access allowed paths. Request approval for destructive operations.'
    FROM agent_config WHERE id = agent_id_param
);

-- Secure agent call - wraps agent_call with policy context
CREATE OR REPLACE MACRO secure_agent_call(agent_id_param, model_name, user_prompt, tools_json) AS (
    SELECT agent_call(
        model_name,
        agent_system_prompt(agent_id_param),
        user_prompt,
        tools_json
    )
);

-- Define local tools for agent (fs_read, fs_write, fs_list, shell_run, web_search)
CREATE OR REPLACE MACRO local_tools_schema() AS (
    SELECT json_array(
        json_object(
            'type', 'function',
            'function', json_object(
                'name', 'fs_read',
                'description', 'Read file contents. Path must be in allowed workspace.',
                'parameters', json_object(
                    'type', 'object',
                    'properties', json_object('path', json_object('type', 'string', 'description', 'File path')),
                    'required', json_array('path')
                )
            )
        ),
        json_object(
            'type', 'function',
            'function', json_object(
                'name', 'fs_list',
                'description', 'List directory contents. Path must be in allowed workspace.',
                'parameters', json_object(
                    'type', 'object',
                    'properties', json_object('path', json_object('type', 'string', 'description', 'Directory path')),
                    'required', json_array('path')
                )
            )
        ),
        json_object(
            'type', 'function',
            'function', json_object(
                'name', 'shell_run',
                'description', 'Execute shell command. Only available in power profile.',
                'parameters', json_object(
                    'type', 'object',
                    'properties', json_object('cmd', json_object('type', 'string', 'description', 'Command to run')),
                    'required', json_array('cmd')
                )
            )
        ),
        json_object(
            'type', 'function',
            'function', json_object(
                'name', 'web_search',
                'description', 'Search the web using DuckDuckGo.',
                'parameters', json_object(
                    'type', 'object',
                    'properties', json_object('query', json_object('type', 'string', 'description', 'Search query')),
                    'required', json_array('query')
                )
            )
        )
    )
);

-- Execute tool call with policy checks
CREATE OR REPLACE MACRO execute_tool(agent_id_param, session_id_param, tool_name, tool_params) AS (
    SELECT CASE tool_name
        WHEN 'fs_read' THEN secure_read(agent_id_param, json_extract_string(tool_params, '$.path'))
        WHEN 'fs_list' THEN secure_ls(agent_id_param, json_extract_string(tool_params, '$.path'))
        WHEN 'shell_run' THEN secure_shell(agent_id_param, json_extract_string(tool_params, '$.cmd'))
        WHEN 'web_search' THEN json_object('results', ddg_instant(json_extract_string(tool_params, '$.query')))
        ELSE json_object('error', 'Unknown tool', 'tool', tool_name)
    END
);

-- =============================================================================
-- ANTHROPIC API COMPATIBILITY (for Claude Cloud mode)
-- =============================================================================

-- Anthropic base URL (set via env or default)
CREATE OR REPLACE MACRO anthropic_base() AS
    COALESCE(getenv('ANTHROPIC_BASE_URL'), 'https://api.anthropic.com');

-- Anthropic chat completion
CREATE OR REPLACE MACRO anthropic_chat(model_name, messages_json, max_tokens) AS (
    SELECT http_post(
        anthropic_base() || '/v1/messages',
        headers := MAP {
            'Content-Type': 'application/json',
            'x-api-key': COALESCE(getenv('ANTHROPIC_API_KEY'), ''),
            'anthropic-version': '2023-06-01'
        },
        body := json_object(
            'model', model_name,
            'messages', json(messages_json),
            'max_tokens', max_tokens
        )
    ).body
);

-- Anthropic chat with tools
CREATE OR REPLACE MACRO anthropic_chat_tools(model_name, messages_json, tools_json, max_tokens) AS (
    SELECT http_post(
        anthropic_base() || '/v1/messages',
        headers := MAP {
            'Content-Type': 'application/json',
            'x-api-key': COALESCE(getenv('ANTHROPIC_API_KEY'), ''),
            'anthropic-version': '2023-06-01'
        },
        body := json_object(
            'model', model_name,
            'messages', json(messages_json),
            'tools', json(tools_json),
            'max_tokens', max_tokens
        )
    ).body
);

-- Unified model call - routes to Ollama or Anthropic based on config
CREATE OR REPLACE MACRO model_call(agent_id_param, user_prompt, tools_json) AS (
    SELECT CASE
        WHEN (SELECT model_backend FROM agent_config WHERE id = agent_id_param) = 'claude_cloud'
        THEN anthropic_chat_tools(
            (SELECT model_name FROM agent_config WHERE id = agent_id_param),
            json_array(json_object('role', 'user', 'content', user_prompt)),
            tools_json,
            4096
        )
        ELSE ollama_chat_with_tools(
            (SELECT model_name FROM agent_config WHERE id = agent_id_param),
            json_array(json_object('role', 'user', 'content', user_prompt)),
            tools_json
        )
    END
);
