# Common Agent Marketplace Workflows

Public reusable GitHub Actions workflows and validation actions for repositories
that publish agent skills and plugins.

This repository intentionally contains only generic marketplace automation:

- skill and plugin manifest validation
- pull-request preview archives
- release archives and installation summaries
- optional npm registry publishing for agents that support npm catalogs

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

## Publishing to an npm registry

The generic archive and its installer are opaque to coding agents: something has
to download and unpack them, which is what the generated installer script does.
Agents can, however, resolve npm packages on their own, so publishing the same
release contents to an npm registry lets them install and update without an
installer.

Enable it on the release workflow:

```yaml
with:
  publish_npm: true
  npm_package_name: "@acme/agent-skills"
  # npm_registry defaults to the Gitea npm registry for gitea_user
secrets:
  GITEA_TOKEN: ${{ secrets.GITEA_TOKEN }}
```

Notes:

- the package is built from the same staged directory as the generic archive, so
  the two can never drift apart
- `package.json` is generated at publish time with the release version, which
  keeps it in step with the plugin manifest versions that release-please bumps
- `npm_package_name` must be scoped, because the scope is what routes installs to
  the registry in `.npmrc`. The scope does not have to match the registry owner:
  Gitea's own example maps an `@test` scope to a `testuser` registry URL
- `NPM_TOKEN` is used when set; otherwise `GITEA_TOKEN` is reused
- publishing fails if any released path is absent from the packed tarball, which
  guards against npm's ignore rules silently dropping `.agents/` or
  `.claude-plugin/`
