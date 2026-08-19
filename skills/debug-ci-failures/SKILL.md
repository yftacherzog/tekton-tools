---
name: debug-ci-failures
description: >-
  Troubleshoot failing Konflux CI pipelines in tekton-tools. Use when a PR check
  fails, the user needs to find logs, interpret task results, or diagnose why a
  specific pipeline stage errored.
---

# Debugging CI Failures

## Finding Logs

Konflux pipeline logs are accessible via:

1. **PR status checks** -- click "Details" on the failing check in the GitHub PR
2. **Konflux console** -- navigate to the PipelineRun in the `konflux-vanguard-tenant` namespace
3. **`tkn` CLI** (if you have cluster access):
   ```bash
   tkn pipelinerun logs <pipelinerun-name> -n konflux-vanguard-tenant
   ```

Each pipeline task's logs appear as a separate step. Look for the first task with
a failed status.

## Pipeline Stages and Common Failures

### test-container-pull-request

| Stage | Common Failure | Fix |
|-------|---------------|-----|
| `yaml-lint` | YAML syntax error or trailing whitespace | Run `pipenv run yamllint .` locally, fix reported lines |
| `run-gitlint` | Missing `Signed-off-by` or non-conventional title | Amend commits: `git commit --amend -s` |
| `run-gitlint` | "No commits found" | Rebase on latest `main` so git history is visible |
| `run-kubelint` | K8s manifest issue | Run `kube-linter lint config/ tasks/ --config .kube-linter.yaml` locally |
| `build-container` | Dockerfile build error | Check `Dockerfile` syntax; image is `ubi9/ubi-minimal` |
| `sast-shell-check` | Shell script issue in built image | Fix shellcheck warnings in task scripts |
| `sast-unicode-check` | Suspicious Unicode characters | Remove non-ASCII characters or use allowed ranges |
| `local-rpms-signature-scan` | Task execution error | Check task YAML for syntax errors; see "Task Failures" below |
| `rpms-signature-scan` | Catalog bundle version fails | Unrelated to your PR; the released task broke against the new image |

### rpms-signature-scan-v02-on-pull-request

| Stage | Common Failure | Fix |
|-------|---------------|-----|
| `tkn-bundle-oci-ta` | Invalid task YAML | Validate YAML structure; ensure `apiVersion: tekton.dev/v1` |
| `build-container` | OCI bundle build failure | Check that `path-context` points to correct directory |
| `sast-shell-check` | Script issues in task steps | Fix shellcheck warnings in the task's `script:` blocks |

### rpms-signature-scan-tests-pull-request

| Stage | Common Failure | Fix |
|-------|---------------|-----|
| `rpms-signature-scan-signed` | Task errors on scan | Check `rpm_verifier` logic; image may have changed |
| `verify-output-signed` | Results don't match expected | See "Understanding Test Results" below |
| `rpms-signature-scan-unsigned` | Same as above | Same as above |
| `rpms-signature-scan-image-index` | Multi-arch resolution failure | Check image-index manifest is intact |

## Understanding Test Results

The `rpms-signature-scan` task produces four results:

### TEST_OUTPUT

JSON string from `make_result_json`. On success:
```json
{"result":"SUCCESS","note":"Task rpms-signature-scan completed successfully"}
```

On error:
```json
{"result":"ERROR","note":"Task rpms-signature-scan failed to scan images. Refer to Tekton task output for details"}
```

### RPMS_DATA

Signature key counts and unsigned RPM information. Format:
```
<key-id>: <count>
unsigned: <count>
```

Expected values for test images:

| Image | Key `199e2f91fd431d51` | Unsigned |
|-------|------------------------|----------|
| `signed-rpms` | 95 | 0 |
| `unsigned-rpms` | 163 | 68 |
| `image_index` | 95 | 0 |

If counts change, the test images may have been rebuilt. Verify the digests in
`.tekton/rpms-signature-scan-tests-pull-request.yaml` still match the actual images.

### IMAGES_PROCESSED

Lists digests that were scanned:
```
digests: [sha256:3ec7a3cd38db...]
```

For image indexes, multiple digests appear (child manifests are resolved).

### SCAN_LOG

Diagnostic log captured from `rpm_verifier` stderr. For ModelCar (OLOT) images,
contains lines like:
```
Selective extraction enabled for <image> (skipping 1 of 7 layers)
```

For regular images this result is empty. If selective extraction is expected but
missing, verify the tools image includes the ModelCar support (commit `0e3925a`+).

## Task Failures: rpms-signature-scan

The task has two steps:

1. **`rpms-signature-scan`** -- runs `rpm_verifier` from `quay.io/konflux-ci/tools`
2. **`output-results`** -- reads results from workdir and formats them

Common issues:

| Symptom | Cause | Fix |
|---------|-------|-----|
| `rpm_verifier` exits non-zero | Image unreachable or auth failure | Check image-url/digest are valid; check network/registry access |
| Status is `ERROR` but RPMs exist | `rpm_verifier` bug or timeout | Check tools image version; may need digest update |
| Empty `RPMS_DATA` | Workdir not shared between steps | Ensure `emptyDir` volume is mounted at `$(params.workdir)` in both steps |
| `make_result_json` not found | Wrong `konflux-test` image | Verify the `output-results` step image digest is current |

## Migration Script Failures

Migration scripts (`migrations/<version>.sh`) require these tools:
- **`yq`** -- YAML processor
- **`jq`** -- JSON processor
- **`pmt`** -- Pipeline Modification Tool (from Konflux)

If a migration fails:
- Check the script exits 0 when the task isn't found in the pipeline file
- Verify `yq` selector syntax matches current pipeline structure
- Test locally: `./migrations/0.2.1.sh path/to/pipeline.yaml`

## GitHub Actions Failures

The only GHA check is AGENTS.md line count:

```
::error::AGENTS.md has X lines, must be <= 300
```

Fix: trim `AGENTS.md` to 300 lines or fewer.

## Re-running Failed Pipelines

- **Konflux pipelines**: push a new commit or close/reopen the PR to retrigger
- **GitHub Actions**: use the "Re-run jobs" button in the Actions tab
- There is no manual trigger mechanism for Konflux PAC pipelines without a git event
