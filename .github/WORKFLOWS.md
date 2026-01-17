# GitHub Actions Workflows Documentation

This document describes all automated workflows configured for the agent-farm repository.

## Overview

The repository uses GitHub Actions for continuous integration, security scanning, dependency management, and automated releases. All workflows follow best practices for Python projects and are optimized for performance with caching strategies and concurrency controls.

## Key Optimizations

All workflows include:
- **Concurrency Controls**: Automatically cancel outdated workflow runs on the same branch/PR
- **Dependency Caching**: All jobs cache uv dependencies for faster execution
- **Manual Triggers**: Support for `workflow_dispatch` to manually run workflows when needed
- **Job Summaries**: Key workflows generate GitHub Actions job summaries for better visibility
- **Parallel Execution**: Independent jobs run in parallel for optimal performance

## Workflows

### 1. CI Workflow (`.github/workflows/ci.yml`)

**Trigger**: Push to main/master, Pull requests, Manual dispatch

**Purpose**: Ensures code quality and functionality

**Jobs**:
- **Lint**: Runs Ruff linter and format checker (with dependency caching)
- **Test**: Runs pytest across Python 3.11 and 3.12 (with test summaries)
- **Docker**: Validates Docker image builds
- **Validate Macros**: Tests SQL macro definitions (with dependency caching)

**Optimizations**:
- ✅ All jobs use uv dependency caching
- ✅ Concurrency control cancels outdated runs
- ✅ Jobs run in parallel for speed
- ✅ Test summaries displayed in GitHub UI

**Status Badge**:
```markdown
[![CI](https://github.com/bjoernbethge/agent-farm/workflows/CI/badge.svg)](https://github.com/bjoernbethge/agent-farm/actions/workflows/ci.yml)
```

**Configuration**:
- Matrix testing: Python 3.11, 3.12
- Caching: uv dependencies cached using `uv.lock` hash
- Docker: Uses BuildKit with GitHub Actions cache

### 2. Release Workflow (`.github/workflows/release.yml`)

**Trigger**: Git tags matching `v*.*.*` (e.g., `v0.1.6`), Manual dispatch

**Purpose**: Automates package distribution

**Jobs**:
1. **Build**: Creates distribution packages (wheel and sdist) with dependency caching
2. **Publish to PyPI**: Uploads to PyPI using trusted publishing
3. **GitHub Release**: Creates release with auto-generated notes
4. **Docker Release**: Builds and pushes multi-arch Docker images to GHCR

**Optimizations**:
- ✅ Build job uses uv dependency caching
- ✅ Concurrency control prevents overlapping releases
- ✅ Jobs run in parallel where possible (PyPI and Docker after build)

**How to Release**:
```bash
# Update version in pyproject.toml
# Commit changes
git add pyproject.toml
git commit -m "chore: bump version to 0.1.6"

# Create and push tag
git tag v0.1.6
git push origin v0.1.6
```

**Artifacts**:
- PyPI package: `pip install agent-farm`
- Docker images: `ghcr.io/bjoernbethge/agent-farm:latest`
- GitHub release with distribution files

**Requirements**:
- PyPI trusted publishing configured for repository
- GHCR write permissions

### 3. Security Workflow (`.github/workflows/security.yml`)

**Trigger**: 
- Push to main/master
- Pull requests
- Weekly schedule (Monday 00:00 UTC)
- Manual dispatch

**Purpose**: Identifies security vulnerabilities

**Jobs**:
- **CodeQL Analysis**: Static analysis for security issues (runs on push/schedule only, not PRs)
- **Dependency Scan**: Checks dependencies for known vulnerabilities using pip-audit (with caching)
- **Docker Scan**: Scans Docker image with Trivy (runs on push/schedule, or PRs with 'security' label)

**Optimizations**:
- ✅ CodeQL skips PRs to reduce redundancy (already runs on push to main)
- ✅ Docker scan skips PRs unless labeled 'security'
- ✅ Dependency scan uses caching for faster execution
- ✅ Concurrency control cancels outdated runs

**Security Alerts**: Results are uploaded to GitHub Security tab

**Best Practices**:
- Results are automatically uploaded to GitHub Security dashboard
- Critical and high severity issues fail the build
- SARIF format for standardized reporting

### 4. Dependency Updates (`.github/workflows/dependencies.yml`)

**Trigger**: 
- Weekly schedule (Monday 08:00 UTC)
- Manual workflow dispatch

**Purpose**: Keeps dependencies up-to-date

**Process**:
1. Updates `uv.lock` with latest compatible versions
2. Runs full test suite
3. Runs linter
4. Creates PR if changes detected

**Optimizations**:
- ✅ Concurrency control ensures only one update runs at a time
- ✅ Manual trigger support for on-demand updates

**PR Details**:
- Branch: `automated/dependency-updates`
- Labels: `dependencies`, `automated`
- Auto-deletes branch after merge

**Manual Trigger**:
```bash
# Via GitHub UI: Actions → Dependency Updates → Run workflow
# Or via GitHub CLI:
gh workflow run dependencies.yml
```

### 5. Code Quality (`.github/workflows/code-quality.yml`)

**Trigger**: Push to main/master, Pull requests, Manual dispatch

**Purpose**: Maintains code quality standards

**Checks**:
- **Quality Checks**:
  - Code complexity (radon) - now properly installed as dev dependency
  - Maintainability index
  - Type checking (if mypy available)
  - TODO/FIXME detection
  - Print statement usage
  - Code coverage reporting (with pytest-cov)
  - Quality summaries in GitHub UI

- **Documentation Check**:
  - Markdown link validation
  - Version consistency
  - Required files presence

- **File Structure**:
  - Required files (README, LICENSE, etc.)
  - Large file detection
  - Python file headers

**Optimizations**:
- ✅ Proper dependency management - radon and pytest-cov in pyproject.toml
- ✅ Dependency caching for faster execution
- ✅ Concurrency control cancels outdated runs
- ✅ Quality metrics displayed in job summaries
- ✅ Jobs run in parallel for speed

**Coverage Reports**: Uploaded to Codecov on pull requests

## Caching Strategy

All workflows use optimized caching:

### uv Dependencies
```yaml
- uses: actions/cache@v4
  with:
    path: ~/.cache/uv
    key: ${{ runner.os }}-uv-${{ hashFiles('**/uv.lock') }}
    restore-keys: |
      ${{ runner.os }}-uv-
```

### Docker Builds
```yaml
cache-from: type=gha
cache-to: type=gha,mode=max
```

## Performance Optimizations

1. **Parallel Jobs**: Independent jobs run in parallel across all workflows
2. **Matrix Strategy**: Tests run concurrently across Python versions
3. **Fail-fast: false**: Complete all tests even if one fails
4. **Smart Caching**: All jobs cache dependencies based on lock file hash
5. **Selective Triggers**: Workflows only run when necessary
6. **Concurrency Controls**: Outdated workflow runs are automatically cancelled
7. **Optimized Security Scans**: CodeQL and Docker scans skip PRs to reduce redundancy

## Secrets and Permissions

### Required Secrets
- `GITHUB_TOKEN`: Automatically provided, used for releases and PRs
- No additional secrets needed (uses OIDC for PyPI)

### Permissions
Each workflow uses minimal required permissions:
- `contents: read` - Read repository content
- `contents: write` - Create releases, update branches
- `pull-requests: write` - Create/update PRs
- `packages: write` - Publish to GHCR
- `security-events: write` - Upload security findings
- `id-token: write` - OIDC authentication for PyPI

## Status Badges

Add these to README.md:

```markdown
[![CI](https://github.com/bjoernbethge/agent-farm/workflows/CI/badge.svg)](https://github.com/bjoernbethge/agent-farm/actions/workflows/ci.yml)
[![Security](https://github.com/bjoernbethge/agent-farm/workflows/Security/badge.svg)](https://github.com/bjoernbethge/agent-farm/actions/workflows/security.yml)
[![Code Quality](https://github.com/bjoernbethge/agent-farm/workflows/Code%20Quality/badge.svg)](https://github.com/bjoernbethge/agent-farm/actions/workflows/code-quality.yml)
```

## Troubleshooting

### CI Failures

**Linting Errors**:
```bash
# Fix automatically
uv run ruff check --fix src/ tests/
uv run ruff format src/ tests/
```

**Test Failures**:
```bash
# Run tests locally
uv sync --dev
uv run pytest tests/ -v
```

**Docker Build Failures**:
```bash
# Test locally
docker build -t agent-farm:test .
```

### Release Issues

**PyPI Upload Fails**:
- Check PyPI trusted publishing is configured
- Verify repository has correct OIDC settings
- Ensure version number is incremented

**Docker Push Fails**:
- Check GHCR permissions
- Verify GITHUB_TOKEN has package write permissions

### Security Alerts

**CodeQL Findings**:
1. Review in Security → Code scanning alerts
2. Fix identified issues
3. Re-run workflow to verify fix

**Dependency Vulnerabilities**:
1. Review in Security → Dependabot alerts
2. Update affected packages: `uv lock --upgrade`
3. Test and commit changes

## Manual Workflow Dispatch

All workflows support manual triggering:

```bash
# Using GitHub CLI
gh workflow run ci.yml
gh workflow run dependencies.yml
gh workflow run security.yml
gh workflow run code-quality.yml
gh workflow run release.yml  # Use with caution!

# Via UI
Actions → Select Workflow → Run workflow
```

**Note**: The release workflow has `workflow_dispatch` but should be used carefully - normally releases are triggered by tags.

## Best Practices

### Before Pushing
1. Run linter: `uv run ruff check --fix src/ tests/`
2. Run tests: `uv run pytest tests/`
3. Build Docker image: `docker build -t agent-farm:test .`

### Creating Pull Requests
- Ensure CI passes before requesting review
- Address security findings if any
- Update documentation if needed

### Creating Releases
1. Update version in `pyproject.toml`
2. Commit and push to main
3. Create and push tag
4. Monitor release workflow

## Monitoring

### GitHub Actions Dashboard
Monitor workflow runs: `https://github.com/bjoernbethge/agent-farm/actions`

### Notifications
Configure notifications in GitHub settings:
- Settings → Notifications → Actions
- Choose email or web notifications for workflow failures

## Future Enhancements

Potential workflow additions:
- [ ] Performance benchmarking
- [ ] Automated changelog generation
- [ ] Integration tests with external services
- [ ] Scheduled smoke tests
- [ ] Docker image size optimization checks
- [ ] License compliance scanning

## Contributing

When adding new workflows:
1. Follow existing naming conventions
2. Use minimal required permissions
3. Implement caching where applicable
4. Add documentation here
5. Test thoroughly before merging

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [uv Documentation](https://github.com/astral-sh/uv)
- [Docker Build Push Action](https://github.com/docker/build-push-action)
- [PyPI Trusted Publishing](https://docs.pypi.org/trusted-publishers/)
