---
name: Bug Report
about: Report a problem or unexpected behavior
title: "fix: description of the bug"
labels: ["bug"]
assignees: []
---

## Bug Description

<!-- Clear description of what went wrong -->

## Steps to Reproduce

1. Step 1
2. Step 2
3. Step 3

## Expected Behavior

<!-- What should have happened? -->

## Actual Behavior

<!-- What actually happened? Include error messages if applicable -->

## Deployment

<!-- Optional but helpful -->
- Target: self-hosted (local machine / local VM) — only path documented today
- Notes: <!-- e.g. fresh install vs existing host -->

## Environment

<!-- Run these commands and paste the output -->
- OS: `cat /etc/os-release`
- Kernel: `uname -r`
- Shell: `echo $SHELL`
- Mise version: `mise --version` (if applicable)

## Logs / Screenshots

<!-- Paste relevant command output or screenshots -->

## Acceptance Criteria

- [ ] Bug is reproducible and confirmed
- [ ] Root cause is identified
- [ ] Fix is implemented and tested
- [ ] Regression test added (if applicable)

## Files Likely Affected

<!-- Optional. -->
- `path/to/file.sh`

Workflow: see [AGENTS.md](../../AGENTS.md).
