# Migration from 0.3 to 0.4

Version 0.4 replaces the inline bash script with the `helm-chart-oci` Go binary
from konflux-ci/tools. Task parameters and results are unchanged.

## Action from users

- Update the task bundle reference to the tekton-tools 0.4 bundle when available.
- No pipeline parameter changes are required.
- Ensure the tools image includes `/opt/app-root/bin/helm-chart-oci`.

## Differences from 0.3

| Area | 0.3 | 0.4 |
|---|---|---|
| Implementation | bash + helm + yq + jq + skopeo | `helm-chart-oci` Go binary |
| Task bundle location | build-definitions | tekton-tools |
| Tools image | `quay.io/konflux-ci/tools` | Same family; requires Go binary |
