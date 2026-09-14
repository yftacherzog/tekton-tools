---
name: add-or-update-task
description: >-
  Step-by-step guide for adding a new Tekton Task or updating an existing one
  in tekton-tools. Use when the user wants to create a task, bump a version,
  write a migration, or needs to know the required file structure.
---

# Adding or Updating a Tekton Task

Reference: [Building Tekton Tasks in Konflux](https://konflux.pages.redhat.com/docs/users/end-to-end/building-tekton-tasks.html)
([source](https://github.com/konflux-ci/docs/blob/main/modules/end-to-end/pages/building-tekton-tasks.adoc))

## Scope

Actively maintained tasks:

- `rpms-signature-scan` (`tasks/rpms-signature-scan/0.2/`)
- `build-helm-chart-oci-ta` (`tasks/build-helm-chart-oci-ta/0.4/`)

Deprecated tasks (`generate-odcs-compose`, `provision-env-with-ephemeral-namespace`) are
pending removal.

Use the rpms pipelines as the default template for bundle build/push. For integration
tests, rpms scans external fixture images; helm clones the repo and verifies chart
pushes — see `build-helm-chart-oci-ta-tests-pull-request.yaml`.

## Directory Layout

```
tasks/
  <name>/
    OWNERS                         # Prow-style approvers list
    <major>.<minor>/
      <name>.yaml                  # Tekton Task definition
      README.md                    # Parameters, results, usage
      MIGRATION.md                 # Required if breaking changes
      migrations/
        <major>.<minor>.<patch>.sh # Automated migration script (if patch version)
```

## Step-by-Step: New Task

### 1. Create the task YAML

```yaml
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: <task-name>
  labels:
    app.kubernetes.io/version: "<major>.<minor>"
spec:
  description: |-
    Short description of what this task does.
  params:
    - name: <param-name>
      type: string
      description: What this parameter does
  results:
    - name: <result-name>
      description: What this result contains
  steps:
    - name: <step-name>
      image: quay.io/konflux-ci/tools@sha256:<digest>
      script: |
        #!/bin/bash
        set -ex
        # task logic here
```

Key rules:
- Images **must** be referenced by digest (`@sha256:...`)
- Use images from `quay.io/konflux-ci/tools` or `quay.io/konflux-ci/konflux-test`
- Set `computeResources` (limits and requests) for each step
- Use `emptyDir` volumes for temporary storage between steps

### 2. Create the OWNERS file

At `tasks/<name>/OWNERS`:

```yaml
# See the OWNERS docs: https://go.k8s.io/owners

approvers:
- github-username-1
- github-username-2
```

### 3. Create the README.md

At `tasks/<name>/<version>/README.md`:

```markdown
# <task-name> task

Short description.

## Parameters
|name|description|default value|required|
|---|---|---|---|
|param-name|What it does|default|true/false|

## Results
|name|description|
|---|---|
|result-name|What it contains|

## Additional info

Any extra context about behavior, dependencies, or gotchas.
```

### 4. Create .tekton/ pipelines

You need three pipeline definitions:

**PR build** (`.tekton/<name>-pull-request.yaml`):
- Trigger: `event == "pull_request" && target_branch == "main"`
- Uses `tkn-bundle-oci-ta` to package task YAML into an OCI bundle
- Runs SAST checks on the bundle
- Set `path-context` to the task version directory

**Push build** (`.tekton/<name>-push.yaml`):
- Trigger: `event == "push" && target_branch == "main" && "tasks/<name>/<version>/***".pathChanged()`
- Same build pipeline but without image expiry
- Output tagged with `{{revision}}` (commit SHA)

**Tests** (`.tekton/<name>-tests-pull-request.yaml`):
- Trigger: `event == "pull_request" && target_branch == "main"`
- Inject the PR's task via PAC annotation:
  `pipelinesascode.tekton.dev/task: tasks/<name>/<version>/<name>.yaml`
- Run the task against known test images
- Add verify steps asserting expected results

Use the existing `rpms-signature-scan-v02-*` or `build-helm-chart-oci-ta-v04-*`
pipelines as templates (same `tekton-bundle-builder-oci-ta` flow).

### 5. Register the Konflux component

The task needs a Konflux component registered in the `konflux-vanguard-tenant` namespace
with a corresponding service account (`build-pipeline-<component-name>`). This is done
outside this repo via the releng gitops repo.

### 6. Set up release pipeline

For the task bundle to reach `quay.io/konflux-ci/tekton-catalog/`, a
`ReleasePlanAdmission` must be configured with policy `tekton-bundle-standard`.
This maps the component to the external registry URL and tags. Both maintained tasks
use the same policy and `push-tekton-task-bundles-to-external-registry` release
pipeline; each component maps to its own catalog repository (for example
`task-rpms-signature-scan` or `task-build-helm-chart-oci-ta`).

### 7. Add build-definitions external-task stub

After the first catalog publish, add (or update) a version directory under
`konflux-ci/build-definitions/external-task/<name>/<version>/` with a
`task_bundle:` line pointing at the published digest:

```yaml
task_bundle: quay.io/konflux-ci/tekton-catalog/task-<name>:<version>@sha256:<digest>
```

Renovate in build-definitions (`vanguard` group in `renovate.json`) keeps this digest
current after the initial commit. If replacing an in-repo task (like
`build-helm-chart-oci-ta` 0.3 in `task/`), plan to archive the old version once
consumers move to the external bundle.

## Updating an Existing Task

### Backwards-compatible change (minor bump)

1. Create a new directory: `tasks/<name>/<major>.<new-minor>/`
2. Copy the task YAML, update `app.kubernetes.io/version` label
3. Add a new README.md
4. Update `.tekton/` pipelines to reference the new path

### Breaking change (major bump)

1. Create a new directory: `tasks/<name>/<new-major>.0/`
2. Write `MIGRATION.md` documenting what users must change
3. Follow all steps for a new minor version
4. Old version directory remains for backwards compatibility

### Patch version (metadata/bundle path changes)

1. Stay in the same version directory
2. Update `app.kubernetes.io/version` label (e.g. `"0.2"` → `"0.2.1"`)
3. Create `migrations/<major>.<minor>.<patch>.sh`

The migration script must:
- Accept a pipeline file path as `$1`
- Exit 0 if no migration needed (task not found in file)
- Use `yq`, `jq`, and `pmt` to modify taskRef references
- See `tasks/rpms-signature-scan/0.2/migrations/0.2.1.sh` as the canonical example

## Checklist


- [ ] Task YAML with digest-pinned images and computeResources
- [ ] OWNERS file at tasks/<name>/
- [ ] README.md documenting params and results
- [ ] MIGRATION.md (if breaking change)
- [ ] migrations/<version>.sh (if patch version)
- [ ] .tekton/<name>-pull-request.yaml
- [ ] .tekton/<name>-push.yaml (with pathChanged CEL filter)
- [ ] .tekton/<name>-tests-pull-request.yaml
- [ ] Konflux component registered
- [ ] ReleasePlanAdmission configured for external registry
- [ ] Renovate includePaths updated in `tekton-tools/renovate.json`
- [ ] `external-task/<name>/<version>/` added in build-definitions (after first publish)
