# GitHub Security Setup

This file documents the GitHub settings that cannot be fully enforced from files in
this repository. Keep the repository files and the GitHub/Terraform settings aligned.

## Repository Files

The repository contains:

- `.github/workflows/check.yml` for CI
- `.github/dependabot.yml` for GitHub Actions dependency updates
- `.github/CODEOWNERS` for ownership of sensitive paths
- `SECURITY.md` for private vulnerability reporting instructions

The required CI status check is:

```text
check
```

GitHub may only allow selecting a required status check after that check has run at
least once on the repository.

## Repository Settings

Recommended repository defaults:

- default branch: `main`
- disable wiki and projects unless the project needs them
- enable issues only if the project accepts public issue tracking
- allow squash merge and/or rebase merge
- disable merge commits
- delete branches after merge

## Main Branch Ruleset

Create an active branch ruleset targeting `main`:

- require pull request before merging
- require status checks before merging
- require required status check: `check`
- require branches to be up to date before merging
- require signed commits
- require linear history
- require conversation resolution before merging
- block force pushes
- block branch deletion

If the repository has only one active maintainer, required approving reviews can block
normal maintenance unless an admin bypass is allowed. When a second trusted maintainer
is available, also enable:

- require at least one approval
- dismiss stale approvals
- require review from CODEOWNERS
- require approval of the most recent reviewable push

## Tag And Release Protection

Create an active tag ruleset targeting `v*`:

- block tag deletion
- block tag updates

Publish releases only from signed annotated tags:

```bash
git tag -s vX.Y.Z -m "dvm vX.Y.Z"
git push origin vX.Y.Z
```

Enable immutable releases in GitHub settings. If a release is bad, publish a new
release instead of replacing the old tag or assets.

## GitHub Actions

Recommended Actions settings:

- default `GITHUB_TOKEN` permissions: read-only contents
- do not allow Actions to create or approve pull requests
- allow local actions only, or allow GitHub-owned actions only if future workflows need
  them
- require approval before running workflows from outside contributors
- do not use self-hosted runners for public pull requests

The current workflow intentionally avoids third-party actions.

## Code Security

Enable:

- dependency graph
- Dependabot alerts
- Dependabot security updates
- secret scanning
- secret scanning push protection
- private vulnerability reporting

CodeQL default setup is optional here because this is a Bash project and the main static
check is ShellCheck in CI.

## Terraform Notes

With the `integrations/github` Terraform provider, these settings usually map to:

- `github_repository` for base repository settings and vulnerability alerts
- `github_repository_ruleset` for the `main` branch and `v*` tag rules
- `github_actions_repository_permissions` for allowed Actions policy
- `github_repository_dependabot_security_updates` for Dependabot security updates

Some newer GitHub security features may not be exposed by the Terraform provider
version in use. Configure those through the GitHub UI or call the GitHub REST API from
Terraform.
