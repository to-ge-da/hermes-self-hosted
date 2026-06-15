# GitHub Templates

This document explains the GitHub templates used in this repository to standardize Issues and Pull Requests.

## Overview

Templates ensure consistent information is provided when:
- Reporting bugs
- Requesting features 
- Describing general tasks
- Submitting pull requests

## Issue Templates

### 🐛 Bug Report
**File:** `.github/ISSUE_TEMPLATE/bug.md`

Use when:
- Something is not working as expected
- You encountered an error
- There is unexpected behavior

Sections include:
- Bug description
- Steps to reproduce
- Expected vs actual behavior
- Environment details (OS, kernel, shell, mise version)
- Logs/screenshots
- Acceptance criteria for resolution

### ✨ Feature Request
**File:** `.github/ISSUE_TEMPLATE/feature.md`

Use when:
- Proposing a new feature
- Suggesting an improvement
- Requesting new functionality

Sections include:
- Summary
- Problem statement
- Proposed solution
- Alternative solutions
- Additional context
- Acceptance criteria

### 📋 Task
**File:** `.github/ISSUE_TEMPLATE/task.md`

Use for:
- General work items
- Refactoring
- Documentation updates
- Chores/maintenance

Sections include:
- Summary and context
- Requirements checklist
- Acceptance criteria
- Proposed approach
- Lifecycle workflow diagram

## Pull Request Template

**File:** `.github/PULL_REQUEST_TEMPLATE.md`

Automatically appears when opening a PR. Includes:
- Summary of changes
- Related issues (auto-closes on merge)
- Changes checklist
- Type of change (feat/fix/docs/refactor/chore/test)
- Testing checklist
- Compliance checklist
- Review notes
- Screenshots/output

## Best Practices

1. **Choose the right template** - Don't use bug template for features
2. **Fill all sections** - Empty sections should be deleted or filled
3. **Be specific** - Vague descriptions delay review
4. **Reference issues** - Link related issues in PRs
5. **Check the boxes** - Actually verify checklist items

## Workflow Integration

Per [AGENTS.md](../AGENTS.md), the workflow is:

```
Issue Created (using template)
    ↓
Branch: feat/... or fix/...
    ↓
Code & Test
    ↓
PR Created (template auto-filled)
    ↓
Hermes Reviews (against checklist)
    ↓
Merge & Close
```

## Maintenance

These templates are living documents. Update them when:
- New project conventions are adopted
- Common information is missing from issues
- Review process changes
- New types of work emerge

To update: edit the files in `.github/ISSUE_TEMPLATE/` and `.github/PULL_REQUEST_TEMPLATE.md`, then open a PR.
