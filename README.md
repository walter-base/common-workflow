# Common Agent Marketplace Workflows

Public reusable GitHub Actions workflows and validation actions for repositories
that publish agent skills and plugins.

This repository intentionally contains only generic marketplace automation:

- skill and plugin manifest validation
- pull-request preview archives
- release archives and installation summaries

Container, infrastructure, deployment, and environment-specific workflows are
kept in the private `Walter0697/common-workflow` repository.

## Reuse

Reference the workflows from a repository workflow with a version tag or commit
SHA, for example:

```yaml
jobs:
  validate:
    uses: walter-base/common-workflow/.github/workflows/agent-marketplace-ci.yaml@master
```

The validator is also available as:

```yaml
uses: walter-base/common-workflow/actions/validate-agent-marketplace@master
```
