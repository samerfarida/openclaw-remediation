# Contributing to openclaw-remediation

Thank you for your interest in contributing. This project is **scoped only to OpenClaw** detection, uninstall, and validation.

## Scope

Contributions must stay **in scope**:

- **In scope**: OpenClaw install detection, uninstall (official + fallback), verification of complete removal, CI validation, reliability and idempotency improvements.
- **Out of scope**: Blocking installation, network containment, credential rotation, incident response/forensics, other agent frameworks or vendors.

Out-of-scope contributions will be closed.

## How to contribute

1. **Fork** the repository and create a branch from `main`.
2. Make your changes. Keep changes focused and documented.
3. **Run lint and tests locally** (see below) so CI is likely to pass.
4. Open a **Pull Request** against `main`.

## PR requirements

- **CI must pass**: The workflow runs **smoke** (script on clean runner), **lint** (ShellCheck + PSScriptAnalyzer), and **test** (install → uninstall → assert clean) on macOS, Linux, and Windows. All jobs must succeed.
- **Branch protection**: Merges to `main` require **smoke**, **lint**, and **test** (or the test matrix) to pass. Do not force-push to shared branches.

Maintainers may request changes before merging.

## Running locally

### Lint

- **Shell (macOS/Linux):** Install `shellcheck` (e.g. `brew install shellcheck`), then run:
  ```bash
  shellcheck scripts/uninstall_macos_linux.sh
  ```
- **PowerShell:** Install PSScriptAnalyzer (`Install-Module -Name PSScriptAnalyzer -Scope CurrentUser`), then run:
  ```powershell
  Invoke-ScriptAnalyzer -Path scripts/ -Severity Error
  ```

### Tests

The full test workflow runs the OpenClaw installer in CI, then runs the uninstall scripts and asserts the system is clean. To run something similar locally:

- Use a **throwaway VM or container** (or CI). Do not run the installer on a machine you care about.
- Check out the repo, then run the workflow steps manually: baseline snapshot → install (e.g. `curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard`) → run uninstall scripts → verify no OpenClaw artifacts remain.

Alternatively, push to a branch and let GitHub Actions run the workflow.

**Smoke job:** CI also runs a fast **smoke** job (no install): it runs the uninstall script on a clean runner and expects exit 0. Use this for quick feedback that the script still runs without syntax/runtime errors.

**Pre-commit (optional):** Install [pre-commit](https://pre-commit.com/) and run `pre-commit install` so ShellCheck runs before each commit. See [.pre-commit-config.yaml](.pre-commit-config.yaml).

## Adding a new artifact type

If OpenClaw adds a **new service, path, or artifact** (e.g. a new launchd label or systemd unit):

1. **Scripts:** Add detection and removal in the appropriate script (`uninstall_macos_linux.sh` or `uninstall_windows.ps1`) following the same pattern (log, then remove; respect dry-run).
2. **Assert clean:** In [.github/workflows/test.yml](.github/workflows/test.yml), extend the **Assert clean** step for your platform so CI fails if that artifact remains after uninstall.
3. **Docs:** Update [docs/compatibility.md](docs/compatibility.md) and the “Tested against” note in README if the install layout changed.
4. **CHANGELOG:** Add an entry under Unreleased.

**Releases:** When cutting a release (tag `v*`), update the [VERSION](VERSION) file at repo root to match the tag (e.g. `1.0.0` for `v1.0.0`) so script logs include the correct `version=` for SIEM. The release workflow will attach VERSION and the scripts to the GitHub Release.

Keep changes in scope (OpenClaw only) and ensure lint + smoke + test all pass.

## Exit codes (scripts)

Uninstall scripts use the following exit codes for MDM/SIEM:

- **0** – Success (clean or already clean).
- **1** – Partial (e.g. CLI uninstall failed but manual cleanup ran).
- **2** – Failure (critical step failed). With `--dry-run` / `-DryRun`, exit 2 means “OpenClaw artifacts present (would be removed).”

## Code of conduct and security

- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) – Expected behavior when participating in the project.
- [SECURITY.md](SECURITY.md) – How to report security concerns.

Thank you for helping keep this repo focused and reliable.
