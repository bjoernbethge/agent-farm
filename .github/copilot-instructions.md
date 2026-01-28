# Agent-Farm: Quick Start Guide for Coding Agents

**Trust these instructions** - validated through testing. Only search if something doesn't work.

**agent-farm** is a DuckDB-powered MCP Server providing SQL macros for LLM agents (web search, Python execution, RAG via SQL).

**Key Facts:**
- **Language:** Python 3.11+, Package Manager: **uv** (NOT pip), Database: DuckDB 1.4.2+
- **Structure:** 190 lines main.py, 800+ lines SQL macros, 1 comprehensive test file

## CRITICAL: Run These Commands (Validated, ~60sec first run)

```bash
# 1. ALWAYS FIRST: Install dependencies (if uv not found: pip install uv)
uv sync --dev

# 2. BEFORE COMMITTING: Lint and format
uv run ruff check --fix src/ tests/
uv run ruff format src/ tests/

# 3. BEFORE COMMITTING: Test (~4sec, expect "1 passed" + 1 warning)
uv run pytest tests/ -v

# 4. Run server (optional)
uv run agent-farm  # or: uv run python -m agent_farm

# 5. Docker (may fail in sandboxed envs with cert errors - expected)
docker build -t agent-farm .
```

## Project Structure

```
agent-farm/
├── .github/
│   ├── workflows/          # CI/CD pipelines
│   │   ├── ci.yml         # Main CI: lint, test, docker, validate-macros
│   │   ├── security.yml   # CodeQL + dependency scan
│   │   ├── code-quality.yml
│   │   ├── dependencies.yml  # Weekly dependency updates
│   │   └── release.yml    # PyPI + Docker publish on tags
│   ├── instructions/       # File-specific coding guidelines
│   │   ├── python-source.instructions.md
│   │   ├── python-tests.instructions.md
│   │   ├── sql-macros.instructions.md
│   │   ├── docker.instructions.md
│   │   └── github-workflows.instructions.md
│   ├── agents/
│   │   └── devops-agent.md  # Specialized DevOps agent
│   ├── CONTRIBUTING.md
│   ├── WORKFLOWS.md        # Detailed workflow documentation
│   └── copilot-instructions.md  # This file
├── src/agent_farm/
│   ├── __init__.py
│   ├── main.py            # 190 lines: Entry point, extension loading, MCP server
│   ├── macros.sql         # 800+ lines: SQL macros for LLM integration
│   └── py.typed
├── tests/
│   ├── test_macros.py     # Main test file with SQL parser
│   └── verify_farm.py     # Verification script
├── scripts/
│   ├── install_extensions.py  # Pre-install DuckDB extensions
│   └── test_extensions.py     # Test extension availability
├── pyproject.toml         # Project metadata, dependencies, ruff config
├── uv.lock               # Locked dependencies
├── Dockerfile            # Multi-stage Python 3.11-slim build
├── mcp.json              # MCP server configuration
└── README.md             # User-facing documentation
```

## Key Files by Purpose

### Making Code Changes
- **Python code:** `src/agent_farm/main.py` (extensions, MCP tables, server startup)
- **SQL macros:** `src/agent_farm/macros.sql` (Ollama, web search, shell, RAG, etc.)
- **Tests:** `tests/test_macros.py` (uses `split_sql_statements()` helper)

### Configuration
- **Dependencies:** `pyproject.toml` (requires-python = ">=3.11", line-length = 100)
- **Linter config:** `[tool.ruff]` section in pyproject.toml (target-version = "py311")
- **Package manager:** `uv.lock` (locked versions, don't edit manually)
- **Docker:** `Dockerfile` (Python 3.11-slim, uv for package management)

### Documentation
- **User guide:** `README.md` (features, installation, usage examples)
- **Contributing:** `.github/CONTRIBUTING.md` (dev setup, branching, commit messages)
- **Workflows:** `.github/WORKFLOWS.md` (detailed CI/CD documentation)
- **Instructions:** `.github/instructions/*.instructions.md` (file-type-specific rules)

## CI/CD Pipelines (GitHub Actions)

### CI Workflow (`.github/workflows/ci.yml`)
**Triggers:** Push to main/master, PRs, manual dispatch
**Jobs:**
1. **lint:** Ruff check + format check (uses uv cache)
2. **test:** pytest on Python 3.11 & 3.12 (matrix build, uses uv cache)
3. **docker:** Docker build (uses GitHub Actions cache)
4. **validate-macros:** Run test_macros.py (uses uv cache)

**Critical:** All jobs use uv dependency caching with `uv.lock` hash as key. Cache path: `~/.cache/uv`

### Security Workflow (`.github/workflows/security.yml`)
**Triggers:** Push, PR, weekly (Monday 00:00 UTC), manual
**Jobs:**
1. **codeql:** Static analysis (skips PRs to reduce redundancy)
2. **dependency-scan:** pip-audit on dependencies
3. **docker-scan:** Trivy scan (skips PRs unless labeled 'security')

### Other Workflows
- **code-quality.yml:** Radon complexity, coverage, markdown links, file structure
- **dependencies.yml:** Weekly updates (Monday 08:00 UTC), creates PRs
- **release.yml:** Triggered by tags matching `v*.*.*`, publishes to PyPI + GHCR

## Common Pitfalls

1. **"Command 'uv' not found"** → `pip install uv` first
2. **"No module named 'ruff'"** → Run `uv sync --dev` (NOT just `uv sync`)
3. **Docker cert errors** → Expected in sandboxed envs, don't fix
4. **Extension load failures** → Normal for `radio`, `shellfs`; tests auto-skip
5. **Test warning "returning non-None"** → Harmless, tests still pass

## Coding Standards (CRITICAL)

**Python** (`src/agent_farm/*.py`): 100 char lines (STRICT), Ruff E/F/I/W rules, type hints for public APIs, print errors to stderr
**SQL Macros** (`src/agent_farm/macros.sql`): Always `CREATE OR REPLACE MACRO`, use `TRY()` for safety, `http_get()`/`http_post()` for HTTP, `json_extract_string()` for JSON
**Tests** (`tests/*.py`): pytest with `:memory:` DB, try-except for extensions, mock external APIs
**Workflows** (`.github/workflows/*.yml`): Cache uv deps with `uv.lock` hash, cancel in-progress runs, minimal permissions

## Making Changes (Pre-Commit Checklist)

```bash
uv sync --dev                              # 1. Update deps
uv run ruff format src/ tests/             # 2. Format
uv run ruff check --fix src/ tests/        # 3. Lint
uv run pytest tests/ -v                    # 4. Test (expect "1 passed")
# Then commit - CI will run same checks
```

**SQL Macro:** Edit `src/agent_farm/macros.sql` → Use `CREATE OR REPLACE MACRO` → Test → Update README if user-facing
**Python Code:** Edit `src/agent_farm/main.py` → 100 char lines, type hints, try-except → Test → Lint → Format
**Workflow:** Edit `.github/workflows/*.yml` → Add concurrency + caching + manual trigger → Update `.github/WORKFLOWS.md`

## Quick Reference

**Deps:** `uv sync --dev` | **Lint:** `uv run ruff check --fix src/ tests/` | **Format:** `uv run ruff format src/ tests/`
**Test:** `uv run pytest tests/ -v` | **Run:** `uv run agent-farm` | **Add pkg:** `uv add pkg-name`

**Remember:** (1) Run `uv sync --dev` first, (2) Use uv not pip, (3) 100 char line limit, (4) Python 3.11+, (5) Test before commit

**More info:** `.github/CONTRIBUTING.md`, `.github/WORKFLOWS.md`, `.github/instructions/*.instructions.md`
