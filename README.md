# ci-workflows

Public reusable GitHub Actions workflows for `nonagenticai` **public** repositories.

## Why this repository exists

GitHub's rule: a **public** repository may only call **public** reusable workflows. Every private
service in this org consumes `gitops-production/.github/workflows/*.yml`, which therefore cannot
be used by any repository once it becomes public. This repository is the public counterpart —
same gates, none of the estate's private plumbing — so a public repository's CI is still one
archetype call rather than a hand-rolled copy per repo.

It also means there is exactly **one** trusted place to change the pipeline. A consumer's
workflow file is ~20 lines:

```yaml
jobs:
  ci:
    if: ${{ !github.event.repository.private }}
    uses: nonagenticai/ci-workflows/.github/workflows/python-service.yml@main
    permissions:
      contents: read
      packages: write
    with:
      image_name: my-service
      src_dir: src
```

While the consumer is still private the job reports **skipped**, never red — so the same file can
land before the public flip and activate with no edit at the flip.

## Workflows

| workflow | for | jobs |
|---|---|---|
| `python-service.yml` | a deployed Python service (uv) | `secret-scan`, `no-private-refs`, `checks`, `image` |
| `python-library.yml` | a Python library (uv) | `secret-scan`, `no-private-refs`, `checks`, `uv build` |

`image` builds on every PR and pushes to `ghcr.io/nonagenticai/<image_name>` (`latest`, `sha-<7>`)
only from `main`. **There is no deploy job**: Flux in `gitops-production` watches the ghcr package
through the service's `ImagePolicy`.

## Rules this repository enforces

1. **`ubuntu-latest` only, never a self-hosted runner.** Every ARC runner group has
   `allows_public_repositories: false`, and it must stay that way: a fork PR can edit `runs-on`, so
   any self-hosted runner open to a public repository is arbitrary untrusted code inside the
   estate network. GitHub-hosted standard runners are free and unlimited on public repos.
2. **Zero repository secrets.** Nothing here reads `secrets.*`. The only token is the automatic
   `github.token` (`contents: read`; `packages: write` on the image job alone, and only from
   `main`). There is no `pull_request_target` and no `workflow_run`.
3. **No private infrastructure in a public tree.** Two gates, both run on every PR:
   - `scripts/secret-scan.sh` — betterleaks (pinned, sha256-verified) in **directory** mode over
     the whole tree, using the repo's own `.betterleaks.toml` or the fleet copy here.
   - `scripts/no-private-refs.sh` — refuses internal-only host names, tailnet addresses, the
     estate's private DNS suffixes and private repository paths in any tracked file (docs and
     fixtures included). The exact patterns live in the script; allowlist:
     `.ci/private-refs.allow` in the consumer.

## What is deliberately absent vs. the private archetype

`gitops-production/.github/workflows/python-service.yml` is the private original. This repository
drops, on purpose:

| dropped | why |
|---|---|
| registry login, the estate's internal registry mirror | a public repo builds from Docker Hub |
| sccache, registry build cache, layer GC | estate-side infrastructure |
| `rmt-drift-guard`, `lock-downgrade-guard` | private composite actions; `uv lock --check` keeps the freshness half |
| Flux receiver, `:latest` promote, `kubectl rollout` | deploy is Flux's job, not the repo's |
| `validate-no-upstream-refs` | that gate *forbids* `docker.io` refs — the exact opposite of what a public repo needs; `no-private-refs` replaces it |

Nothing else is intentionally different. When the private archetype gains a gate, decide
explicitly whether the public one needs it, and record that here.

## Selftest

`.github/workflows/selftest.yml` runs every reusable workflow against `fixtures/` on this
repository's own push/PR. **It is the acceptance gate for the archetype**: a consumer may not be
flipped to a workflow variant the selftest has not proven.

## Consumers (2026-11)

- `coding-ai`, `coding-analysis`, `coding-containers`, `coding-gateway`, `coding-github`,
  `coding-realtime`, `coding-repo-jobs`, `coding-security`, `coding-testing` → `python-service.yml`
- `coding-client` → `python-library.yml`

Libraries are consumed as git dependencies, not from a package index:

```toml
[tool.uv.sources]
coding-client = { git = "https://github.com/nonagenticai/coding-client", rev = "<sha>" }
```

## Maintenance

- The custom rules in `.betterleaks.toml` must stay identical to
  `gitops-production/.betterleaks.toml`. If you change one, change both.
- Consumers pin `@main`. A change here reaches every consumer on its next run — the selftest is
  what makes that safe.
