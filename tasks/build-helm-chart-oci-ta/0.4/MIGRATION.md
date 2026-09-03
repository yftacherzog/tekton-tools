# Migration from 0.3 to 0.4

Version 0.4 replaces the inline bash script with the `helm-chart-oci` Go binary
from konflux-ci/tools. Task parameters and results match 0.3, with one
additional optional parameter for chart naming.

## Action from users

- Update the task bundle reference to the tekton-tools 0.4 bundle when available.
- No pipeline parameter changes are required unless you want to preserve
  `Chart.yaml` names instead of rewriting them from `IMAGE` (see
  `OVERWRITE_CHART_NAME` below).
- Ensure the tools image includes `/opt/app-root/bin/helm-chart-oci`.

## New parameter: `OVERWRITE_CHART_NAME`

| Value | Behavior |
|---|---|
| `true` (default) | Same as 0.3: rewrite `Chart.yaml` `name` from the `IMAGE` repository basename |
| `false` | Keep `Chart.yaml` `name`; push to `oci://<parent>/<chart-name>:<version>` |

Product teams building the same chart from multiple Konflux components should set
`OVERWRITE_CHART_NAME=false` and point `IMAGE` at the shared chart delivery
repository (for example `quay.io/org/product-chart:tag`).

## Differences from 0.3

| Area | 0.3 | 0.4 |
|---|---|---|
| Implementation | bash + helm + yq + jq + skopeo | `helm-chart-oci` Go binary |
| Task bundle location | build-definitions | tekton-tools |
| Tools image | `quay.io/konflux-ci/tools` | Same family; requires Go binary |
