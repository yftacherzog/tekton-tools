---
name: ci-cd-quirks
description: >-
  Non-obvious CI/CD details, environment quirks, and gotchas specific to
  tekton-tools. Use when the user is confused by CI behavior, asks about
  Konflux pipelines, Renovate, or needs to understand how the CI environment
  differs from expectations.
---

# CI/CD Quirks

## Primary CI Is Konflux, Not GitHub Actions

The real quality gate lives in `.tekton/` (Pipelines-as-Code PipelineRuns running
in a Konflux cluster). GitHub Actions (`.github/workflows/`) only does two things:

- `lint.yaml` -- validates `AGENTS.md` is under 300 lines
- `fullsend.yaml` -- dispatches the fullsend AI agent for PR review/triage

All linting, building, SAST, and task execution tests run in Konflux.

## PAC Task Injection

PR pipelines can test **uncommitted task changes** from the PR branch using the
`pipelinesascode.tekton.dev/task` annotation:

```yaml
pipelinesascode.tekton.dev/task: tasks/rpms-signature-scan/0.2/rpms-signature-scan.yaml
```

This makes the task available as a local `Task` kind in the pipeline. The
`test-container-pull-request` pipeline uses this to run the PR's version of
`rpms-signature-scan` alongside the published catalog version -- both scan the
same built image so you can compare behavior.

## Dual rpms-signature-scan Execution (rpms only)

`test-container-pull-request` runs `rpms-signature-scan` **twice**:

1. `local-rpms-signature-scan` -- the PR branch version (via PAC injection above)
2. `rpms-signature-scan` -- the released catalog bundle from
   `quay.io/konflux-ci/tekton-catalog/task-rpms-signature-scan:0.2@sha256:...`

Both run against the freshly-built root container. This catches regressions where
the PR's changes break something that the released version handles correctly.

`build-helm-chart-oci-ta` does not run in `test-container-pull-request`. It has a
dedicated integration pipeline (`build-helm-chart-oci-ta-tests-pull-request`) that
clones the PR source, runs the task twice (overwrite and `OVERWRITE_CHART_NAME=false`),
and verifies chart pushes with `skopeo`.

## Trusted-Artifacts Build Path

Task bundle builds (for example `rpms-signature-scan-v02-pull-request` or
`build-helm-chart-oci-ta-v04-pull-request`) use the Konflux trusted-artifacts pipeline:

```
init → git-clone-oci-ta → prefetch-dependencies → tkn-bundle-oci-ta → build-image-index → SAST → apply-tags
```

The `-oci-ta` suffix means artifacts are passed via OCI rather than PVC workspaces.
This is a Konflux-specific pattern -- you won't find these tasks in the upstream
Tekton catalog.

## Renovate Manages Image Digests

Renovate auto-updates container image digests in:
- `tasks/rpms-signature-scan/0.2/**`
- `tasks/build-helm-chart-oci-ta/0.4/**`
- `.tekton/**`

Configured in `renovate.json`. Key implications:
- **Do not manually update digests** in those paths -- Renovate will overwrite them
- `quay.io/konflux-ci/tools` updates are scheduled "at any time" (no delay)
- If you need a new image version, either wait for Renovate or update the tag/digest
  and expect Renovate to open a follow-up PR later

## Namespace and Service Accounts

All pipelines run in namespace `konflux-vanguard-tenant` with dedicated service accounts:

| Pipeline | Service Account |
|----------|----------------|
| `test-container-*` | `build-pipeline-test-container` |
| `rpms-signature-scan-v02-*` | `build-pipeline-rpms-signature-scan-v02` |
| `build-helm-chart-oci-ta-v04-*` | `build-pipeline-build-helm-chart-oci-ta-v04` |
| `build-helm-chart-oci-ta-tests-*` | `build-pipeline-build-helm-chart-oci-ta-v04` |

These are pre-provisioned in the Konflux tenant. You cannot run these pipelines
outside that namespace without recreating the RBAC setup.

## Test Images Are Pinned by Digest

The integration test pipeline (`rpms-signature-scan-tests-pull-request`) uses images
from `quay.io/vanguard_tests/` pinned by digest:

| Image | Digest |
|-------|--------|
| `signed-rpms:latest` | `sha256:3ec7a3cd38db...` |
| `unsigned-rpms:latest` | `sha256:076ed8309d59...` |
| `image_index:latest` | `sha256:da4f388bb1f5...` |

If these images are ever rebuilt or deleted, the integration tests will break.
The digests are what matter -- the `:latest` tag is just for human readability.

## kube-linter Comes from Tekton Catalog Git Resolver

The `run-kubelint` step in `test-container-pull-request` resolves the task
from GitHub at runtime:

```yaml
taskRef:
  resolver: git
  params:
  - name: url
    value: https://github.com/tektoncd/catalog.git
  - name: revision
    value: main
  - name: pathInRepo
    value: task/kube-linter/0.1/kube-linter.yaml
```

This means it always uses the latest `main` branch version. If the upstream task
breaks, our CI breaks -- but this is rare.

## Image Expiry on PR Builds

PR-built images have `image-expires-after: 5d`. They auto-delete from the registry
after 5 days. Push builds (tagged with commit SHA) do not expire.

## CEL Expressions for Triggers

Push pipelines use CEL expressions to conditionally trigger:

```yaml
pipelinesascode.tekton.dev/on-cel-expression: >-
  event == "push" && target_branch == "main" && "tasks/rpms-signature-scan/0.2/***".pathChanged()
```

The `rpms-signature-scan-v02-on-push` only runs when files under the task directory
actually change. It does NOT run on every push to main.

## How Task Updates Reach build-definitions

The release flow is the same for each maintained task. After merging to `main`:

1. **Push pipeline** (path-filtered, e.g. `rpms-signature-scan-v02-on-push` or
   `build-helm-chart-oci-ta-v04-on-push`) builds the task bundle and pushes the
   workload image to `quay.io/redhat-user-workloads/.../<component>:{commit-sha}`
2. **Release pipeline** triggers automatically via `ReleasePlanAdmission` (policy:
   `tekton-bundle-standard`). It pushes the bundle to the mapped catalog repository
   with tags like `<major.minor>`, `<major.minor>-{git_sha}`, and `{oci_version}`
3. **Renovate** in [`konflux-ci/build-definitions`](https://github.com/konflux-ci/build-definitions)
   detects the new digest and opens a PR to update the matching `external-task/` file
4. Once that PR merges, the updated task is available in the build-definitions catalog

| Task | Component | Catalog repository | external-task path |
|------|-----------|-------------------|-------------------|
| `rpms-signature-scan` 0.2 | `rpms-signature-scan-v02` | `task-rpms-signature-scan` | `external-task/rpms-signature-scan/0.2/` |
| `build-helm-chart-oci-ta` 0.4 | `build-helm-chart-oci-ta-v04` | `task-build-helm-chart-oci-ta` | `external-task/build-helm-chart-oci-ta/0.4/` |

Push pipelines only run when files under their task directory change, so unrelated
task merges do not rebuild each other. Each component release maps to a separate
catalog repository — no collision between tasks.

The first `external-task/` commit needs a real published digest; Renovate handles
subsequent updates. The release pipeline is
`push-tekton-task-bundles-to-external-registry` from `konflux-ci/release-service-catalog`.
