# GitHub Templates

This document explains the GitHub templates used in this repository to standardize Issues and Pull Requests.

## Overview

Templates ensure consistent information when:

- Reporting bugs
- Proposing features
- Describing scoped tasks
- Submitting pull requests

## Issue Templates

### Bug Report

**File:** `.github/ISSUE_TEMPLATE/bug.md`

Use when something is not working as expected.

Sections include:

- Bug description
- Steps to reproduce
- Expected vs actual behavior
- Deployment context (optional; self-hosted today)
- Environment details (OS, kernel, shell, mise version)
- Logs/screenshots
- Acceptance criteria

### Feature Request

**File:** `.github/ISSUE_TEMPLATE/feature.md`

Use when proposing a new capability or enhancement.

Sections include:

- Summary
- Problem statement
- Proposed solution
- Alternative solutions
- Additional context
- Acceptance criteria

### Task

**File:** `.github/ISSUE_TEMPLATE/task.md`

Use for scoped implementation work:

- Documentation updates
- Chores/maintenance
- Refactors
- Follow-up coding once an approach is clear

Sections include:

- Summary and context
- Requirements checklist
- Acceptance criteria
- Proposed approach (optional)

Prefer **Feature** for open-ended capability proposals; prefer **Task** when the work is already scoped.

## Pull Request Template

**File:** `.github/PULL_REQUEST_TEMPLATE.md`

Automatically appears when opening a PR. Includes:

- Summary of changes
- Related issues (auto-closes on merge)
- Changes list
- Type of change (feat/fix/docs/refactor/chore/test)
- Testing checklist
- Compliance checklist
- Review notes
- Screenshots/output

## Best Practices

1. Choose the right template
2. Fill or delete empty sections
3. Be specific — vague descriptions delay review
4. Reference related issues in PRs
5. Actually verify checklist items

## Workflow Integration

Typical flow for this repository:

```
Issue Created (using template)
    ↓
Branch: feat/... or fix/... or chore/...
    ↓
Code & Test
    ↓
PR Created (template auto-filled)
    ↓
Review
    ↓
Merge & Close
```

## Maintenance

Update these templates when project conventions change, common information is missing, or the review process changes.

Edit files under `.github/ISSUE_TEMPLATE/` and `.github/PULL_REQUEST_TEMPLATE.md`, then open a PR.
