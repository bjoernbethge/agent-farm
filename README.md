<div align="center">
  <img src="https://raw.githubusercontent.com/bjoernbethge/agent-farm/master/assets/farm.jpg" alt="Agent Farm" width="100%" />
</div>

# 🚜 Agent Farm 🦆

[![Python](https://img.shields.io/badge/Python-3.11+-blue.svg)](https://www.python.org)
[![DuckDB](https://img.shields.io/badge/DuckDB-1.1.0+-yellow.svg)](https://duckdb.org)
[![Ollama](https://img.shields.io/badge/Ollama-Run%20Locally-white.svg)](https://ollama.com)
[![Docker](https://img.shields.io/badge/Docker-Enabled-blue.svg)](https://www.docker.com)
[![MCP](https://img.shields.io/badge/MCP-Protocol-green.svg)](https://modelcontextprotocol.io)
[![Query Farm](https://img.shields.io/badge/Powered%20By-Query%20Farm-orange.svg)](https://query.farm)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**🌾 DuckDB-powered MCP Server with SQL macros for LLM agents - Web Search, Python execution, RAG, and more.**

[DuckDB](https://duckdb.org) • [Ollama](https://ollama.com) • [Docker](https://www.docker.com) • [Query Farm](https://query.farm)

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🦆 **MCP Server** | Exposes DuckDB as an MCP server for Claude and other LLM clients |
| 🔍 **Auto-Discovery** | Automatically discovers MCP configurations from standard locations |
| 🤖 **LLM Integration** | SQL macros for calling Ollama models (local and cloud) |
| 🛠️ **Tool Calling** | Full function calling support for agentic workflows |
| 🌐 **Web Search** | DuckDuckGo and Brave Search integration |
| 💻 **Shell Execution** | Run shell commands and Python code via UV |
| 📄 **Web Scraping** | Fetch and extract text from web pages |
| 🧠 **RAG Support** | Embeddings and vector similarity search |
| 📦 **Rich Extensions** | Pre-configured with useful DuckDB extensions |

---

## 📦 DuckDB Extensions

| Extension | Type | Description |
|-----------|------|-------------|
| `httpfs` | Core | HTTP/S3 filesystem access |
| `json` | Core | JSON parsing and extraction |
| `icu` | Core | International unicode support |
| `vss` | Core | Vector similarity search |
| `ducklake` | Core | Delta Lake / Iceberg support |
| `lindel` | Core | Linear algebra operations |
| `http_client` | Community | HTTP GET/POST requests |
| `duckdb_mcp` | Community | MCP protocol support |
| `jsonata` | Community | JSONata query language |
| `shellfs` | Community | Shell command execution |
| `zipfs` | Community | ZIP file access |

---

## 🚀 Installation

**Using pip:**
```bash
pip install agent-farm
```

**Using uv (recommended):**
```bash
uv add agent-farm
```

**From source:**
```bash
git clone https://github.com/bjoernbethge/agent-farm.git
cd agent-farm
uv sync --dev
```

---

## 🎯 Quick Start

**Run the MCP server:**
```bash
agent-farm
```

**Or as a module:**
```bash
python -m agent_farm
```

---

## 🌾 SQL Macros

### 🤖 Cloud LLM Models (via Ollama)

```sql
SELECT deepseek('Explain quantum computing');
SELECT kimi_think('Solve this step by step: ...');
SELECT qwen3_coder('Write a Python function for...');
SELECT gemini('Summarize this text...');
```

### 🔍 Web Search

```sql
SELECT ddg_instant('Python programming');
SELECT ddg_abstract('machine learning');
SELECT brave_search('DuckDB tutorial');
```

### 💻 Shell & Python Execution

```sql
SELECT shell('ls -la');
SELECT py('print(2+2)');
SELECT py_with('requests', 'import requests; print(requests.__version__)');
SELECT py_script('script.py');
```

### 🌐 Web Scraping

```sql
SELECT fetch('https://example.com');
SELECT fetch_text('https://example.com');
SELECT fetch_json('https://api.example.com/data');
SELECT fetch_ua('https://example.com');  -- with User-Agent
```

### 📁 File & Git Operations

```sql
SELECT read_file('path/to/file.txt');
SELECT git_status();
SELECT git_log(10);
SELECT git_diff();
```

### 🧠 RAG & Embeddings

```sql
SELECT embed('Hello world');
SELECT semantic_score('query', 'document');
SELECT rag_query('What is the price?', 'Product: Widget, Price: 49.99');
SELECT rag_think('Complex question', 'Long context...');
```

### ⚡ Power Macros

```sql
SELECT search_and_summarize('What is DuckDB?');
SELECT analyze_page('https://example.com', 'What is this page about?');
SELECT review_code('src/main.py');
SELECT explain_code('src/main.py');
SELECT generate_py('fibonacci function');
```

---

## 🐳 Docker

```bash
docker build -t agent-farm .
docker run -v /data:/data -p 8080:8080 agent-farm
```

---

## 📋 Requirements

- 🐍 Python >= 3.11
- 🦆 DuckDB >= 1.1.0
- 🦙 Ollama (for LLM features)

---

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

<div align="center">
  <b>🚜 Happy Farming! 🦆</b>
</div>
