# Spec Engine

The **Spec Engine** is the central "Spec-OS" for all agents in Agent Farm. It uses DuckDB with specialized extensions to manage ALL specifications including agents, skills, workflows, APIs, JSON schemas, templates, and more.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    LLM Agent (e.g., Pia)                    │
└─────────────────────────┬───────────────────────────────────┘
                          │ MCP Protocol
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    Spec Engine (DuckDB)                     │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │  minijinja  │ │ json_schema │ │  duckdb_mcp │           │
│  │ (templates) │ │ (validate)  │ │ (MCP client)│           │
│  └─────────────┘ └─────────────┘ └─────────────┘           │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    spec_objects                         ││
│  │  agents | skills | apis | schemas | templates | ...     ││
│  └─────────────────────────────────────────────────────────┘│
│  ┌─────────────┐ ┌─────────────┐                           │
│  │  httpserver │ │    macros   │                           │
│  │ (HTTP API)  │ │  (SQL ops)  │                           │
│  └─────────────┘ └─────────────┘                           │
└─────────────────────────────────────────────────────────────┘
```

## Extensions

The Spec Engine uses these DuckDB extensions:

| Extension | Purpose | Source |
|-----------|---------|--------|
| `minijinja` | Render MiniJinja templates for prompts/plans | Community |
| `json_schema` | Validate JSON payloads against schemas | Community |
| `duckdb_mcp` | MCP client/server integration | Community |
| `httpserver` | Expose DuckDB as HTTP OLAP API | Community |
| `json` | JSON manipulation | Core |
| `httpfs` | HTTP filesystem access | Core |
| `http_client` | HTTP requests | Community |

## Schema

### Core Tables

```sql
-- Main specification objects
CREATE TABLE spec_objects (
    id       INTEGER PRIMARY KEY,
    kind     TEXT NOT NULL,      -- 'agent', 'skill', 'api', 'schema', ...
    name     TEXT NOT NULL,
    version  TEXT NOT NULL,
    status   TEXT NOT NULL,      -- 'draft', 'active', 'deprecated'
    summary  TEXT NOT NULL,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Documentation for specs
CREATE TABLE spec_docs (
    id        INTEGER PRIMARY KEY,
    object_id INTEGER REFERENCES spec_objects(id),
    doc       TEXT NOT NULL,
    doc_format TEXT DEFAULT 'markdown'
);

-- JSON payloads for specs
CREATE TABLE spec_payloads (
    id         INTEGER PRIMARY KEY,
    object_id  INTEGER REFERENCES spec_objects(id),
    payload    JSON,
    schema_ref TEXT  -- Reference to a schema spec for validation
);
```

### Spec Kinds

| Kind | Description |
|------|-------------|
| `agent` | Agent configurations (role, model, tools, prompts) |
| `skill` | Skill definitions with tool schemas |
| `api` | API specifications (OpenAI, Claude, custom) |
| `protocol` | Protocol definitions (MCP, HTTP, GraphQL) |
| `schema` | JSON Schemas for validation |
| `task_template` | MiniJinja templates for task plans |
| `prompt_template` | MiniJinja templates for prompts |
| `workflow` | Multi-step workflow definitions |
| `ui` | UI component specifications |
| `open_response` | Open Response format specs |
| `org` | Organization configurations |
| `tool` | Individual tool definitions |

### Convenience Views

- `spec_agents_view` - All agent specs with docs and payloads
- `spec_skills_view` - All skill specs
- `spec_apis_view` - All API specs
- `spec_schemas_view` - All JSON schemas
- `spec_task_templates_view` - All task templates
- `spec_prompt_templates_view` - All prompt templates
- `spec_full_view` - All specs joined with docs and payloads

## MCP Tools

### spec_list

List specs by kind with optional filters.

**Input:**
```json
{
    "kind": "agent",           // Optional: filter by kind
    "status": "active",        // Optional: filter by status
    "limit": 50                // Optional: max results
}
```

**Output:**
```json
[
    {"id": 10, "kind": "agent", "name": "pia", "version": "1.0.0", "status": "active", "summary": "..."}
]
```

**SQL:**
```sql
SELECT * FROM spec_list_by_kind('agent');
```

### spec_get

Get a single spec by ID or by kind+name.

**Input (by ID):**
```json
{"id": 10}
```

**Input (by kind+name):**
```json
{
    "kind": "agent",
    "name": "pia",
    "version": "1.0.0"  // Optional, defaults to latest
}
```

**Output:**
```json
{
    "id": 10,
    "kind": "agent",
    "name": "pia",
    "version": "1.0.0",
    "status": "active",
    "summary": "Pia is the master planner agent...",
    "doc": "# Pia - Master Planner Agent\n...",
    "payload": {"name": "Pia", "role": "planner", ...},
    "schema_ref": "agent_config_schema"
}
```

**SQL:**
```sql
SELECT * FROM spec_get('agent', 'pia');
SELECT * FROM spec_get_by_id(10);
```

### spec_search

Search specs by query string (searches name, summary, and docs).

**Input:**
```json
{"query": "planner"}
```

**Output:**
```json
[
    {"id": 10, "kind": "agent", "name": "pia", "version": "1.0.0", "status": "active", "summary": "..."}
]
```

**SQL:**
```sql
SELECT * FROM spec_search('planner');
SELECT * FROM spec_search_full('planner');  -- Also searches doc content
```

### render_from_template

Render a MiniJinja template with context.

**Input:**
```json
{
    "template_name": "plan_pia_swarm",
    "context": {
        "task_name": "Deploy User Service",
        "objective": "Deploy the user management microservice",
        "steps": [
            {"name": "Build", "org": "DevOrg", "tool": "build_service", "input": {}}
        ],
        "success_criteria": ["All tests pass", "Service responds"]
    }
}
```

**Output:**
```json
{
    "rendered": "# Execution Plan: Deploy User Service\n\n**Created by**: Pia\n..."
}
```

**SQL:**
```sql
SELECT spec_render_template('plan_pia_swarm', '{"task_name": "Test", ...}');
SELECT spec_render('Hello {{ name }}!', '{"name": "World"}');
```

### validate_payload_against_spec

Validate a JSON payload against a spec's schema.

**Input:**
```json
{
    "kind": "schema",
    "name": "agent_config_schema",
    "payload": {"name": "test", "role": "planner"}
}
```

**Output:**
```json
{
    "ok": true,
    "errors": []
}
```

Or on validation failure:
```json
{
    "ok": false,
    "errors": ["Property 'role' must be one of: planner, executor, researcher, orchestrator, specialist"]
}
```

**SQL:**
```sql
SELECT spec_validate('agent_config_schema', '{"name": "test", "role": "planner"}');
SELECT spec_is_valid('agent_config_schema', '{"name": "test"}');
```

### MCP Remote Helpers

```sql
-- List resources from a remote MCP server
SELECT * FROM mcp_list_remote('server_name');

-- List tools from a remote MCP server
SELECT * FROM mcp_list_tools_remote('server_name');

-- Call a remote MCP tool
SELECT mcp_call_remote_tool('server_name', 'tool_name', '{"arg": "value"}');

-- Get a resource from a remote MCP server
SELECT mcp_get_remote_resource('server_name', 'resource://uri');
```

## HTTP API

The Spec Engine can be exposed over HTTP using the `httpserver` extension.

### Starting the Server

**Via environment:**
```bash
export SPEC_ENGINE_HTTP_PORT=9999
export SPEC_ENGINE_API_KEY=your-secret-key
agent-farm
```

**Via SQL:**
```sql
SELECT spec_http_start(9999, 'your-secret-key');
```

### Example Requests

```bash
# List all specs
curl -X POST \
     -H "X-API-Key: your-secret-key" \
     -d "SELECT * FROM api_specs_list" \
     http://localhost:9999/

# Get a specific spec
curl -X POST \
     -H "X-API-Key: your-secret-key" \
     -d "SELECT * FROM spec_full_view WHERE name = 'pia'" \
     http://localhost:9999/

# Search specs
curl -X POST \
     -H "X-API-Key: your-secret-key" \
     -d "SELECT * FROM spec_search('planner')" \
     http://localhost:9999/

# Get statistics
curl -X POST \
     -H "X-API-Key: your-secret-key" \
     -d "SELECT * FROM api_stats" \
     http://localhost:9999/
```

## Agent Usage Guide

### For Pia (Planner Agent)

Pia should use the Spec Engine to:

1. **Discover capabilities**: Use `spec_list` to find available skills and tools
2. **Get agent configs**: Use `spec_get` to fetch agent configurations
3. **Create plans**: Use `render_from_template` with `plan_pia_swarm`
4. **Validate inputs**: Use `validate_payload_against_spec` before executing

**Example workflow:**

```
1. User: "Build a REST API for user management"

2. Pia: spec_list(kind="skill") -> Find available skills

3. Pia: spec_get(kind="skill", name="duckdb-spec-engine") -> Get skill details

4. Pia: render_from_template(
       template_name="plan_pia_swarm",
       context={
           "task_name": "Build User API",
           "objective": "Create a REST API for user CRUD operations",
           "steps": [
               {"name": "Design Schema", "org": "ResearchOrg", "tool": "spec_search"},
               {"name": "Implement API", "org": "DevOrg", "tool": "code_write"},
               {"name": "Write Tests", "org": "DevOrg", "tool": "test_write"},
               {"name": "Deploy", "org": "OpsOrg", "tool": "deploy_service"}
           ],
           "success_criteria": ["API responds to /users", "Tests pass", "Deployed"]
       }
   )

5. Pia: Execute plan by calling organizations
```

### For Other Agents

All agents can:

1. **Look up their own config**: `spec_get(kind="org", name="DevOrg")`
2. **Find available tools**: `spec_list(kind="tool")`
3. **Validate payloads**: Before sending to external APIs
4. **Render prompts**: Use prompt templates for consistent communication

## File Structure

```
db/
├── spec_engine_init.sql     # Extension installation
├── spec_engine_schema.sql   # Table definitions
├── spec_engine_macros.sql   # SQL macros
├── spec_engine_seed.sql     # Initial data
└── spec_engine_http.sql     # HTTP API configuration

src/agent_farm/
├── spec_engine.py           # Python module
├── main.py                  # Entry point (integrates Spec Engine)
└── ...

docs/
└── spec_engine.md           # This documentation
```

## Seed Data

The Spec Engine comes pre-seeded with:

### Schemas
- `agent_config_schema` - Validates agent configurations
- `skill_config_schema` - Validates skill definitions
- `task_template_schema` - Validates template payloads

### Agents
- `pia` - Master planner agent for orchestrating swarm workflows

### Skills
- `duckdb-spec-engine` - Core skill for spec management
- `surrealdb-memory` - Persistent agent memory
- `n8n-orchestrator` - Workflow orchestration

### Templates
- `plan_pia_swarm` - MiniJinja template for execution plans
- `agent_system_prompt` - Base template for agent prompts

### Protocols/APIs
- `mcp` - Model Context Protocol specification
- `openai-chat-completions` - OpenAI API specification

### Organizations
- `DevOrg` - Development organization
- `OpsOrg` - Operations organization
- `ResearchOrg` - Research organization
- `StudioOrg` - Creative/docs organization
- `OrchestratorOrg` - Coordination organization

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DUCKDB_DATABASE` | Path to DuckDB database | `:memory:` |
| `SPEC_ENGINE_DB` | Path to Spec Engine database | `db/spec_engine.db` |
| `SPEC_ENGINE_HTTP_PORT` | HTTP server port | None (disabled) |
| `SPEC_ENGINE_API_KEY` | HTTP API authentication key | None |
