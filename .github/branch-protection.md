# Branch Protection Rules for `main`

This document outlines the recommended branch protection rules for the `main` branch to ensure code quality and prevent accidental direct pushes.

## Recommended Settings

Navigate to Settings → Branches → Add rule for `main` branch:

### Basic Settings
- **Branch name pattern**: `main`
- ✅ **Require a pull request before merging**
  - ✅ Require approvals: 1
  - ✅ Dismiss stale pull request approvals when new commits are pushed
  - ✅ Require review from CODEOWNERS (if applicable)

### Status Checks
- ✅ **Require status checks to pass before merging**
  - ✅ Require branches to be up to date before merging
  - **Required status checks**:
    - `Julia 1.10 - ubuntu-latest - x64`
    - `Julia 1.11 - ubuntu-latest - x64`
    - `Build Docker Image`
    - `Code Quality`
    - `Build System Image`

### Additional Protections
- ✅ **Require conversation resolution before merging**
- ✅ **Require signed commits** (optional but recommended)
- ✅ **Include administrators** (enforce rules for admins too)
- ✅ **Restrict who can push to matching branches**
  - Add specific teams/users who can merge PRs

### Force Push Protection
- ✅ **Do not allow force pushes**
- ✅ **Do not allow deletions**

## GitHub Rulesets (Alternative)

For organizations using GitHub Rulesets (Settings → Rules → Rulesets):

1. Create a new ruleset named "Main Branch Protection"
2. Target: `main` branch
3. Enforcement: Active
4. Rules:
   - Restrict creations
   - Restrict updates (require pull request)
   - Restrict deletions
   - Require pull request (1 approval)
   - Require status checks:
     - Julia 1.10 tests
     - Julia 1.11 tests
     - Docker build
     - Code quality
   - Block force pushes

## Bypass List

Consider allowing bypass for:
- Bot accounts (e.g., dependabot, semantic-release bot)
- Emergency fixes (with audit trail)

## Implementation

To implement these rules:

1. Go to: https://github.com/pteradigm/RxInferKServe.jl/settings/branches
2. Click "Add rule" or "Add ruleset"
3. Configure as described above
4. Save changes

**Note**: You need admin access to the repository to configure branch protection rules.