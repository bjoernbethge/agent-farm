-- ============================================================================
-- Spec Engine Unified Schema
-- ============================================================================
-- The Spec Engine is the central "Spec-OS" for all agents.
-- This schema manages ALL specifications: agents, skills, workflows,
-- APIs/protocols, JSON schemas, templates, and more.
-- ============================================================================

-- Drop existing tables if they exist (clean slate - no backwards compatibility)
DROP TABLE IF EXISTS spec_payloads CASCADE;
DROP TABLE IF EXISTS spec_docs CASCADE;
DROP TABLE IF EXISTS spec_objects CASCADE;

-- ============================================================================
-- Core Spec Tables
-- ============================================================================

-- Main specification objects table
CREATE TABLE spec_objects (
    id          INTEGER PRIMARY KEY,
    kind        VARCHAR NOT NULL,   -- 'agent', 'skill', 'api', 'protocol', 'schema',
                                    -- 'open_response', 'ui', 'workflow', 'task_template',
                                    -- 'prompt_template', 'tool', 'org'
    name        VARCHAR NOT NULL,
    version     VARCHAR NOT NULL DEFAULT '1.0.0',
    status      VARCHAR NOT NULL DEFAULT 'draft',  -- 'draft', 'active', 'deprecated'
    summary     VARCHAR NOT NULL,
    created_at  TIMESTAMP DEFAULT current_timestamp,
    updated_at  TIMESTAMP DEFAULT current_timestamp,

    -- Ensure unique name+version per kind
    UNIQUE (kind, name, version)
);

-- Documentation for spec objects
CREATE TABLE spec_docs (
    id          INTEGER PRIMARY KEY,
    object_id   INTEGER NOT NULL,   -- References spec_objects(id)
    doc         VARCHAR NOT NULL,
    doc_format  VARCHAR DEFAULT 'markdown',  -- 'markdown', 'plaintext', 'html'
    created_at  TIMESTAMP DEFAULT current_timestamp
);

-- Payloads (JSON data) for spec objects
CREATE TABLE spec_payloads (
    id          INTEGER PRIMARY KEY,
    object_id   INTEGER NOT NULL,   -- References spec_objects(id)
    payload     VARCHAR,            -- JSON stored as VARCHAR for compatibility
    schema_ref  VARCHAR,            -- Optional: reference to a 'schema' spec for validation
    created_at  TIMESTAMP DEFAULT current_timestamp
);

-- ============================================================================
-- Indexes for Performance
-- ============================================================================

CREATE INDEX idx_spec_objects_kind ON spec_objects(kind);
CREATE INDEX idx_spec_objects_name ON spec_objects(name);
CREATE INDEX idx_spec_objects_status ON spec_objects(status);
CREATE INDEX idx_spec_objects_kind_name ON spec_objects(kind, name);
CREATE INDEX idx_spec_docs_object_id ON spec_docs(object_id);
CREATE INDEX idx_spec_payloads_object_id ON spec_payloads(object_id);

-- ============================================================================
-- Convenience Views by Kind
-- ============================================================================

-- Agents view
CREATE OR REPLACE VIEW spec_agents_view AS
SELECT
    o.id, o.kind, o.name, o.version, o.status, o.summary,
    o.created_at, o.updated_at,
    d.doc,
    p.payload,
    p.schema_ref
FROM spec_objects o
LEFT JOIN spec_docs d ON d.object_id = o.id
LEFT JOIN spec_payloads p ON p.object_id = o.id
WHERE o.kind = 'agent';

-- Skills view
CREATE OR REPLACE VIEW spec_skills_view AS
SELECT
    o.id, o.kind, o.name, o.version, o.status, o.summary,
    o.created_at, o.updated_at,
    d.doc,
    p.payload,
    p.schema_ref
FROM spec_objects o
LEFT JOIN spec_docs d ON d.object_id = o.id
LEFT JOIN spec_payloads p ON p.object_id = o.id
WHERE o.kind = 'skill';

-- APIs view
CREATE OR REPLACE VIEW spec_apis_view AS
SELECT
    o.id, o.kind, o.name, o.version, o.status, o.summary,
    o.created_at, o.updated_at,
    d.doc,
    p.payload,
    p.schema_ref
FROM spec_objects o
LEFT JOIN spec_docs d ON d.object_id = o.id
LEFT JOIN spec_payloads p ON p.object_id = o.id
WHERE o.kind = 'api';

-- Protocols view
CREATE OR REPLACE VIEW spec_protocols_view AS
SELECT
    o.id, o.kind, o.name, o.version, o.status, o.summary,
    o.created_at, o.updated_at,
    d.doc,
    p.payload,
    p.schema_ref
FROM spec_objects o
LEFT JOIN spec_docs d ON d.object_id = o.id
LEFT JOIN spec_payloads p ON p.object_id = o.id
WHERE o.kind = 'protocol';

-- Schemas view (JSON Schemas for validation)
CREATE OR REPLACE VIEW spec_schemas_view AS
SELECT
    o.id, o.kind, o.name, o.version, o.status, o.summary,
    o.created_at, o.updated_at,
    d.doc,
    p.payload,
    p.schema_ref
FROM spec_objects o
LEFT JOIN spec_docs d ON d.object_id = o.id
LEFT JOIN spec_payloads p ON p.object_id = o.id
WHERE o.kind = 'schema';

-- Task templates view
CREATE OR REPLACE VIEW spec_task_templates_view AS
SELECT
    o.id, o.kind, o.name, o.version, o.status, o.summary,
    o.created_at, o.updated_at,
    d.doc,
    p.payload,
    p.schema_ref
FROM spec_objects o
LEFT JOIN spec_docs d ON d.object_id = o.id
LEFT JOIN spec_payloads p ON p.object_id = o.id
WHERE o.kind = 'task_template';

-- Prompt templates view
CREATE OR REPLACE VIEW spec_prompt_templates_view AS
SELECT
    o.id, o.kind, o.name, o.version, o.status, o.summary,
    o.created_at, o.updated_at,
    d.doc,
    p.payload,
    p.schema_ref
FROM spec_objects o
LEFT JOIN spec_docs d ON d.object_id = o.id
LEFT JOIN spec_payloads p ON p.object_id = o.id
WHERE o.kind = 'prompt_template';

-- Tools view
CREATE OR REPLACE VIEW spec_tools_view AS
SELECT
    o.id, o.kind, o.name, o.version, o.status, o.summary,
    o.created_at, o.updated_at,
    d.doc,
    p.payload,
    p.schema_ref
FROM spec_objects o
LEFT JOIN spec_docs d ON d.object_id = o.id
LEFT JOIN spec_payloads p ON p.object_id = o.id
WHERE o.kind = 'tool';

-- Workflows view
CREATE OR REPLACE VIEW spec_workflows_view AS
SELECT
    o.id, o.kind, o.name, o.version, o.status, o.summary,
    o.created_at, o.updated_at,
    d.doc,
    p.payload,
    p.schema_ref
FROM spec_objects o
LEFT JOIN spec_docs d ON d.object_id = o.id
LEFT JOIN spec_payloads p ON p.object_id = o.id
WHERE o.kind = 'workflow';

-- UIs / Open Responses view
CREATE OR REPLACE VIEW spec_ui_view AS
SELECT
    o.id, o.kind, o.name, o.version, o.status, o.summary,
    o.created_at, o.updated_at,
    d.doc,
    p.payload,
    p.schema_ref
FROM spec_objects o
LEFT JOIN spec_docs d ON d.object_id = o.id
LEFT JOIN spec_payloads p ON p.object_id = o.id
WHERE o.kind IN ('ui', 'open_response');

-- Organizations view
CREATE OR REPLACE VIEW spec_orgs_view AS
SELECT
    o.id, o.kind, o.name, o.version, o.status, o.summary,
    o.created_at, o.updated_at,
    d.doc,
    p.payload,
    p.schema_ref
FROM spec_objects o
LEFT JOIN spec_docs d ON d.object_id = o.id
LEFT JOIN spec_payloads p ON p.object_id = o.id
WHERE o.kind = 'org';

-- ============================================================================
-- Full Spec View (all specs with docs and payloads)
-- ============================================================================

CREATE OR REPLACE VIEW spec_full_view AS
SELECT
    o.id, o.kind, o.name, o.version, o.status, o.summary,
    o.created_at, o.updated_at,
    d.doc,
    d.doc_format,
    p.payload,
    p.schema_ref
FROM spec_objects o
LEFT JOIN spec_docs d ON d.object_id = o.id
LEFT JOIN spec_payloads p ON p.object_id = o.id;

-- ============================================================================
-- Sequences for auto-incrementing IDs
-- ============================================================================

CREATE SEQUENCE IF NOT EXISTS spec_objects_seq START 1;
CREATE SEQUENCE IF NOT EXISTS spec_docs_seq START 1;
CREATE SEQUENCE IF NOT EXISTS spec_payloads_seq START 1;
