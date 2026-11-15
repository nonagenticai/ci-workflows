# ci-workflows

[![CI](https://github.com/nonagenticai/ci-workflows/actions/workflows/selftest.yml/badge.svg)](https://github.com/nonagenticai/ci-workflows/actions/workflows/selftest.yml)
[![Release](https://img.shields.io/github/v/release/nonagenticai/ci-workflows)](https://github.com/nonagenticai/ci-workflows/releases)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

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

Five reusable workflows. Each is called as
`uses: nonagenticai/ci-workflows/.github/workflows/<workflow>@main`. Every job in every workflow is
gated on `${{ !github.event.repository.private }}`, so a consumer can add the call while its
repository is still private (the jobs report **skipped**) and activate at the public flip.

| workflow | use for | jobs | workflow outputs |
|---|---|---|---|
| `python-service.yml` | a deployed Python service (uv, Docker image) | `secret-scan`, `no-private-refs`, `checks`, `image` | — |
| `python-library.yml` | a Python library packaged with uv — gates + wheel build, never published | `secret-scan`, `no-private-refs`, `checks` | — |
| `node-service.yml` | a Node service (npm) with a Dockerfile | `secret-scan`, `no-private-refs`, `checks`, `image` | `image_ref`, `image_digest` |
| `go-service.yml` | a Go service (Go module) with a Dockerfile | `secret-scan`, `no-private-refs`, `checks`, `image` | `image_ref`, `image_digest` |
| `image-only.yml` | one container image from any Dockerfile, with no language checks | `secret-scan`, `no-private-refs`, `image` | `image_ref`, `image_digest` |

`secret-scan` and `no-private-refs` are identical in all five: they check out the **caller's tree**
plus `nonagenticai/ci-workflows@main` and run `scripts/secret-scan.sh` and
`scripts/no-private-refs.sh` (see **Rules** below).

### `python-service.yml` — a deployed Python service (uv)

`checks` runs: `uv lock --check`; ruff lint and format check; `ty` type check; pytest; optionally
an ephemeral `pgvector/pgvector:pg18` Postgres and an ephemeral Redis, a single-head check plus
`alembic upgrade head`, DB integration tests and oracle modules; then bandit and pip-audit.
`image` builds the repo's Dockerfile and runs the optional smoke snippet.

| input | type | default | meaning |
|---|---|---|---|
| `image_name` | string | **required** | image name under `ghcr.io/<registry_owner>/` |
| `registry_owner` | string | `nonagenticai` | ghcr namespace |
| `python_version` | string | `3.14` | Python version for `setup-uv` |
| `uv_version` | string | `0.13.7` | uv version; matches the `ghcr.io/astral-sh/uv` pin in consumer Dockerfiles |
| `src_dir` | string | `src` | source directory for bandit and ty, relative to `working_directory` |
| `test_dir` | string | `tests/` | pytest target |
| `working_directory` | string | `.` | project directory relative to the repository root |
| `dockerfile` | string | `Dockerfile` | Dockerfile path, relative to `working_directory` |
| `uv_sync_args` | string | `--all-extras` | arguments passed to `uv sync` |
| `has_postgres` | boolean | `false` | start an ephemeral pgvector/pg18 and export `DATABASE_URL` + `PG_*` |
| `database_name` | string | `""` | database name; empty = `<image_name>_ci` |
| `alembic` | boolean | `false` | assert a single alembic head, then `alembic upgrade head` |
| `db_bootstrap_cmd` | string | `""` | shell run in the same shell as the DB-integration pytest, immediately before it |
| `integration_test_select` | string | `""` | pytest target for DB integration tests; empty = skip |
| `has_redis` | boolean | `false` | start an ephemeral Redis sidecar |
| `extra_apt` | string | `""` | space-separated apt packages installed before `uv sync` |
| `oracle_modules` | string | `""` | space-separated importable modules executed after the test suite |
| `pip_audit_ignores` | string | `""` | space-separated `--ignore-vuln` flags |
| `enable_security_scans` | boolean | `true` | run bandit and pip-audit |
| `build_smoke` | string | `""` | shell snippet run against the built image with `$IMAGE_REF`; empty = skip |
| `build_timeout_minutes` | number | `60` | `image` job cap |
| `test_timeout_seconds` | number | `300` | per-test timeout injected when the project has no pytest-timeout |
| `integration_test_timeout_seconds` | number | `600` | per-test timeout for integration tests |

No workflow outputs. Pushes `:sha-<7>` and `:latest` only on a `push` or `workflow_dispatch` to
`main`; a PR builds and smokes the image but pushes nothing.

### `python-library.yml` — a Python library (uv)

`checks` runs: `uv lock --check`; ruff lint and format check; `ty`; pytest; `uv build` (wheel and
sdist); bandit; pip-audit. It **never publishes** — public consumers take the library as a git
dependency, and PyPI cannot use a reusable workflow as a Trusted Publisher
(`pypi/warehouse#11096`), so a repo that publishes to PyPI keeps its own `publish.yml`.

| input | type | default | meaning |
|---|---|---|---|
| `python_version` | string | `3.14` | Python version for `setup-uv` |
| `uv_version` | string | `0.13.7` | uv version |
| `src_dir` | string | `src` | source directory for bandit and ty |
| `test_dir` | string | `tests/` | pytest target |
| `working_directory` | string | `.` | project directory relative to the repository root |
| `uv_sync_args` | string | `--all-extras` | arguments passed to `uv sync` |
| `extra_apt` | string | `""` | space-separated apt packages |
| `pip_audit_ignores` | string | `""` | space-separated `--ignore-vuln` flags |
| `enable_security_scans` | boolean | `true` | run bandit and pip-audit |

No workflow outputs and no image job.

### `node-service.yml` — a Node service with a Dockerfile

`checks` installs with the lockfile (`npm ci` by default), then runs lint and test; all three
commands are inputs, and the defaults use `--if-present` so a repo without the script stays green.
No dependency cache is used: a cache a fork PR can write is a cache the next `main` build trusts.

| input | type | default | meaning |
|---|---|---|---|
| `image_name` | string | **required** | image name under `ghcr.io/<registry_owner>/` |
| `registry_owner` | string | `nonagenticai` | ghcr namespace |
| `working_directory` | string | `.` | directory containing `package.json` and the Dockerfile |
| `node_version` | string | `24` | Node version to install; the repo's `engines.node` must accept it |
| `install_cmd` | string | `npm ci --no-audit --no-fund` | install command |
| `lint_cmd` | string | `npm run lint --if-present` | lint command |
| `test_cmd` | string | `npm test --if-present` | test command |
| `dockerfile` | string | `Dockerfile` | Dockerfile path, relative to `working_directory` |
| `build_smoke` | string | `""` | shell snippet run against the built image with `$IMAGE_REF`; empty = skip |
| `build_timeout_minutes` | number | `60` | `image` job cap |
| `ci_workflows_ref` | string | `""` | ref of the caller's tree to build in the `image` job; empty = the triggering ref. The scan jobs always read ci-workflows `main`. Only the selftest passes it. |

Outputs: `image_ref` (`:sha-<7>` on main, `:pr-<7>` for a same-repo PR, empty on a fork PR) and
`image_digest` (empty when nothing was pushed).

### `go-service.yml` — a Go service with a Dockerfile

`checks` runs `go mod verify`, `go vet ./...` and `go test ./... -count=1`. `go vet` + `go test` are
the gate, not golangci-lint. `working_directory` defaults to `src` because a Go module in a service
repo conventionally lives beside its Dockerfile; the image build context is the **repository root**,
so `dockerfile` is root-relative.

| input | type | default | meaning |
|---|---|---|---|
| `image_name` | string | **required** | image name under `ghcr.io/<registry_owner>/` |
| `registry_owner` | string | `nonagenticai` | ghcr namespace |
| `working_directory` | string | `src` | directory containing `go.mod` |
| `go_version` | string | `1.26` | Go version; `setup-go` accepts `1.26`, `1.26.x` or `stable` |
| `dockerfile` | string | `Dockerfile` | Dockerfile path, relative to the **repository root** |
| `build_smoke` | string | `""` | shell snippet run against the built image with `$IMAGE_REF`; empty = skip |
| `build_timeout_minutes` | number | `45` | `image` job cap |
| `ci_workflows_ref` | string | `""` | ref of the caller's tree to build in the `image` job; empty = the triggering ref. The scan jobs always read ci-workflows `main`. Only the selftest passes it. |

Outputs: `image_ref`, `image_digest` — same contract as `node-service.yml`.

### `image-only.yml` — one container image from any Dockerfile

For an image that is not the repository's language service — e.g. `coding-containers`' two
`codegraph-runtime` images. Deliberately single-image: a second image is a second caller job, not
an input. There is no language `checks` job; `image` builds the Dockerfile with the given build
args and runs the optional smoke snippet.

| input | type | default | meaning |
|---|---|---|---|
| `image_name` | string | **required** | image name under `ghcr.io/<registry_owner>/` |
| `registry_owner` | string | `nonagenticai` | ghcr namespace |
| `working_directory` | string | `.` | build context and the Dockerfile's root |
| `dockerfile` | string | `Dockerfile` | Dockerfile path, relative to `working_directory` |
| `build_args` | string | `""` | newline-separated `KEY=VALUE` build args |
| `build_smoke` | string | `""` | shell snippet run against the built image with `$IMAGE_REF`; empty = skip |
| `build_timeout_minutes` | number | `60` | `image` job cap |
| `ci_workflows_ref` | string | `""` | ref of the caller's tree to build in the `image` job; empty = the triggering ref. The scan jobs always read ci-workflows `main`. Only the selftest passes it. |

Outputs: `image_ref`, `image_digest` — same contract as `node-service.yml`.

### Publishing

`node-service.yml`, `go-service.yml` and `image-only.yml` follow one publish contract:

- `push` / `workflow_dispatch` / `schedule` on `main` → push `:sha-<7>` and `:latest`
- a same-repository PR → push `:pr-<7>` after the smoke, so a later job can consume it
- a fork PR → build + smoke only, nothing pushed, empty `image_ref`

`python-service.yml` pushes only the `main` tags; its PR runs never push or export an image ref.
All pushes use `docker buildx build --push --provenance=mode=max`, so the pushed manifest carries a
SLSA provenance attestation naming the repository, commit and workflow. **There is no deploy job**:
Flux in `gitops-production` watches the ghcr package through the service's `ImagePolicy`.

## Rules this repository enforces

1. **`ubuntu-latest` only, never a self-hosted runner.** Every ARC runner group has
   `allows_public_repositories: false`, and it must stay that way: a fork PR can edit `runs-on`, so
   any self-hosted runner open to a public repository is arbitrary untrusted code inside the
   estate network. GitHub-hosted standard runners are free and unlimited on public repos.
2. **Zero repository secrets.** Nothing here reads `secrets.*`. The only token is the automatic
   `github.token` (`contents: read` at workflow level; `packages: write` on the `image` job alone).
   Images are pushed only from `main`, except the `:pr-<7>` tag the three Dockerfile-first
   workflows push for a same-repository PR. There is no `pull_request_target` and no
   `workflow_run`.
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

Seventeen repositories call a workflow here, all at `@main`, each through its own
`.github/workflows/ci.yml` unless noted:

| workflow | consumer repositories |
|---|---|
| `python-service.yml` | `coding-ai`, `coding-analysis`, `coding-containers`, `coding-gateway`, `coding-github`, `coding-realtime`, `coding-repo-jobs`, `coding-security`, `coding-testing`, `python-test-executor` (10) |
| `python-library.yml` | `coding-client` (1) |
| `node-service.yml` | `cpp-test-executor`, `csharp-test-executor`, `java-test-executor`, `javascript-test-executor`, `rust-test-executor` (5) |
| `go-service.yml` | `go-test-executor` (1) |
| `image-only.yml` | `coding-containers` — `.github/workflows/runtime-image.yaml`, two caller jobs (`codegraph-runtime`, `codegraph-runtime-rust`) (1) |

`coding-containers` therefore appears twice: `python-service.yml` builds the service image, and
`image-only.yml` builds its two runtime images. Verify the list with
`gh api repos/nonagenticai/<repo>/contents/.github/workflows` and the `uses:` line in each file.

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

## Trust model (this repository is a supply chain)

Every consumer runs one of the five workflows at `@main`; the image-building consumers grant
`packages: write`. **A commit merged here executes in all 17 consumer repositories on their next
run**, and the images it pushes are what Flux deploys. That is the price of "fix once, apply
everywhere", and these are the controls that carry it:

| control | where |
|---|---|
| every third-party action is pinned to a **commit SHA** with a `# vX.Y.Z` comment | all workflows; Dependabot updates the SHA and the comment |
| `cooldown: default-days: 7` on Dependabot — a yanked release never reaches us | `.github/dependabot.yml` |
| **`lint` job**: actionlint + zizmor (auditor persona, gates medium and above) on every PR | `selftest.yml`, a required check |
| template values reach `run:` through `env:`, never interpolated into the script text | every step that takes an input |
| `permissions: contents: read` at workflow level; `packages: write` only on the image job | all workflows |
| `persist-credentials: false` on every checkout — no token left in `.git/config` | all workflows |
| pushed images carry a SLSA provenance attestation (`--provenance=mode=max`) | the publish steps |
| CODEOWNERS, non-fast-forward, PR required, secret scanning + push protection | repository settings |

**Residual risk, stated plainly:** merges here are self-approved (a single-owner org cannot review
its own PRs), so the branch ruleset and the `lint` gate are the only pre-merge controls. Treat
write access to this repository as equivalent to write access to all 17 consumers.

## Security

Report vulnerabilities privately through the repository's Security tab — see
[`SECURITY.md`](SECURITY.md). Do not open a public issue for a security problem.

## Contributing

Issues and pull requests are welcome. See
[`CONTRIBUTING.md`](https://github.com/nonagenticai/.github/blob/main/CONTRIBUTING.md) for the
organisation-wide rules; setup, test and lint commands are in this README. Commits carry DCO
sign-off.

## Licensing

The code in this repository is Apache-2.0 and needs no licence key to build, test or run.
It contains no licence-enforcement code: the Apache-2.0 licence in [`LICENSE`](LICENSE) is the
only licence that applies, and no licence server is involved.

## License

Apache-2.0 — see [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
