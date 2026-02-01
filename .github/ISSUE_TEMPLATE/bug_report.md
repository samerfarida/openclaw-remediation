---
name: Bug report
about: Report a bug or unexpected behavior (in scope: detection, uninstall, validation)
title: "[Bug] "
labels: bug
assignees: ''
---

## Scope check
This repo is **scoped only to OpenClaw** detection, uninstall, and validation. Out-of-scope (e.g. blocking install, other vendors) will be closed.

- [ ] This is about the uninstall scripts or CI (detection, removal, assert clean, lint).

## Describe the bug
A clear description of what went wrong.

## Platform
- [ ] macOS
- [ ] Linux
- [ ] Windows

## Steps to reproduce
1. ...
2. ...
3. ...

## Expected behavior
What you expected.

## Actual behavior
What actually happened (include exit code and log snippet if relevant).

## Logs
Path: `/var/log/openclaw_removal.log` (macOS/Linux) or `C:\ProgramData\OpenClawRemoval.log` (Windows). Paste a redacted snippet.

## Environment
- OS and version:
- How OpenClaw was installed (install.sh, install.ps1, npm, etc.):
- Script version or commit:
