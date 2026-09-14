---
name: pr-definition-of-done
description: >-
  Checklist of requirements for a merge-ready pull request in tekton-tools.
  Use when the user asks what is needed to merge a PR, wants a review checklist,
  or is preparing changes for submission.
---

# PR Definition of Done

## Commit Messages

Enforced by gitlint (`.gitlint`) in CI.

- **Conventional commit title**: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, etc.
- **Max 72 characters** for title and body lines
- **Blank line** between title and body
- **`Signed-off-by` trailer required** -- use `git commit -s`

Example:

```
feat(rpms-signature-scan): add support for image indexes

Handle multi-arch image indexes by resolving all child digests
before scanning.

Signed-off-by: Your Name <your.email@example.com>
```

## Linters Must Pass

All three run in the `test-container-pull-request` Konflux pipeline:

| Linter | Command | Config |
|--------|---------|--------|
| yamllint | `pipenv run yamllint .` | `.yamllint` |
| gitlint | `gitlint --fail-without-commits --commits "origin/main..HEAD"` | `.gitlint` |
| kube-linter | `kube-linter lint config/ tasks/ --config .kube-linter.yaml` | `.kube-linter.yaml` |

Additionally, GitHub Actions checks `AGENTS.md` stays under 300 lines.

## Image References

- All container images **must use digest** (`@sha256:...`), never tags
- Task step images come from `quay.io/konflux-ci/tools` or `quay.io/konflux-ci/konflux-test`
- Base images use `registry.access.redhat.com` (e.g. `ubi8/ubi-minimal`, `ubi9/ubi-minimal`)
- Renovate auto-updates digests in `tasks/rpms-signature-scan/0.2/**`,
  `tasks/build-helm-chart-oci-ta/0.4/**`, and `.tekton/**` -- do not manually update
  digests that Renovate manages

## Task Changes

Actively maintained: `rpms-signature-scan` and `build-helm-chart-oci-ta`. Deprecated
tasks (`generate-odcs-compose`, `provision-env-with-ephemeral-namespace`) are pending
removal.

### Version bumping

| Change type | What to do |
|-------------|------------|
| Backwards-compatible | Bump minor version: create `tasks/<name>/<major>.<new-minor>/` |
| Breaking (params removed/renamed, behavior change) | Bump major version: create `tasks/<name>/<new-major>.0/` |
| Patch (bundle path, metadata) | Keep same directory, update `app.kubernetes.io/version` label |

### Required files per version directory

| File | Required | Purpose |
|------|----------|---------|
| `<name>.yaml` | Yes | Tekton Task definition |
| `kustomization.yaml` | Yes | Kustomize resource list |
| `README.md` | Yes | Parameters, results, usage docs |
| `MIGRATION.md` | If breaking | User-facing migration steps |
| `migrations/<version>.sh` | If patch | Automated migration script |

### Migration scripts

Patch version migrations (e.g. `0.2.1`) need a script at `migrations/<version>.sh` that:
- Takes a pipeline file path as `$1`
- Uses `yq`, `jq`, and `pmt` (pipeline modification tool) to update references
- Exits 0 if no migration needed
- See `tasks/rpms-signature-scan/0.2/migrations/0.2.1.sh` as the canonical example

### OWNERS file

Each task needs `tasks/<name>/OWNERS` listing approvers in Prow format:

```yaml
approvers:
  - github-username-1
  - github-username-2
```

## CI Pipelines

For task changes, ensure the corresponding `.tekton/` pipelines exist:

| Pipeline | Trigger | Purpose |
|----------|---------|---------|
| `test-container-pull-request.yaml` | PR to main | Lints + builds root container + runs rpms-signature-scan against it |
| `<name>-pull-request.yaml` | PR to main | Build task bundle |
| `<name>-push.yaml` | Push to main | Publish task bundle (tagged with commit SHA) |
| `<name>-tests-pull-request.yaml` | PR to main | Run task integration tests (external images or in-repo fixtures) |

### After merge: propagation to build-definitions

Once the push pipeline builds the bundle, a Konflux release pipeline automatically
pushes it to the mapped `quay.io/konflux-ci/tekton-catalog/task-<name>` repository.
Renovate in `konflux-ci/build-definitions` then detects the new digest and opens a
PR to update the matching `external-task/<name>/<version>/` file.

| Task | external-task path |
|------|-------------------|
| `rpms-signature-scan` 0.2 | `external-task/rpms-signature-scan/0.2/rpms-signature-scan.yaml` |
| `build-helm-chart-oci-ta` 0.4 | `external-task/build-helm-chart-oci-ta/0.4/build-helm-chart-oci-ta.yaml` |

No manual sync is needed after the initial `external-task/` commit with a real digest.
The catalog entry becomes available in build-definitions once the Renovate PR merges.

## Final Checklist

- [ ] Commit message: conventional format + Signed-off-by
- [ ] All images referenced by digest
- [ ] Version bumped correctly (if task change)
- [ ] README.md updated (if task change)
- [ ] MIGRATION.md added (if breaking change)
- [ ] OWNERS file present (if new task)
- [ ] .tekton/ pipelines exist (if new task)
- [ ] `external-task/<name>/<version>/` in build-definitions (after first catalog publish)
