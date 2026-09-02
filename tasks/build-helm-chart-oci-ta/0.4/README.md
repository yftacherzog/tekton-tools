# build-helm-chart-oci-ta task

Packages and pushes a Helm chart to an OCI repository using the `helm-chart-oci`
Go binary from [konflux-ci/tools](https://github.com/konflux-ci/tools).

Version 0.4 replaces the inline bash script from 0.3 with `helm-chart-oci`.
Parameters and results match 0.3, plus optional chart naming control.

## Parameters
|name|description|default value|required|
|---|---|---|---|
|CA_TRUST_CONFIG_MAP_KEY|Key in the CA ConfigMap|ca-bundle.crt|false|
|CA_TRUST_CONFIG_MAP_NAME|CA ConfigMap name|trusted-ca|false|
|CHART_CONTEXT|Path relative to SOURCE_CODE_DIR where the chart lives|dist/chart/|false|
|COMMIT_SHA|Git commit SHA for version resolution||true|
|IMAGE_MAPPINGS|JSON array of image mappings|[]|false|
|IMAGE|Full output image reference with tag||true|
|SOURCE_ARTIFACT|Trusted Artifact URI for application source||true|
|SOURCE_CODE_DIR|Directory under workingDir where source is extracted|source|false|
|TAG_PREFIX|Git tag prefix for version resolution|helm-|false|
|VALUES_FILES|Values files for image substitution|[values.yaml]|false|
|VERSION_SUFFIX|Suffix appended to computed chart version|""|false|
|CHART_VERSION|Explicit chart version (skips git resolution)|""|false|
|APP_VERSION|Explicit appVersion override|""|false|
|OVERWRITE_CHART_NAME|When true, rewrite Chart.yaml name from IMAGE basename (0.3 behavior). When false, preserve Chart.yaml name.|true|false|

## Results
|name|description|
|---|---|
|IMAGE_DIGEST|Digest of the pushed OCI chart artifact|
|IMAGE_URL|Repository and semver tag of the pushed chart|

## Usage

`SOURCE_CODE_DIR` must match where `use-trusted-artifact` extracts the clone
(default `source`). `CHART_CONTEXT` is relative to that directory.

### Basic TaskRun

```yaml
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  name: build-helm-chart-oci-ta
spec:
  taskRef:
    name: build-helm-chart-oci-ta
  params:
    - name: IMAGE
      value: quay.io/myorg/mychart:on-pr-abc123
    - name: COMMIT_SHA
      value: abc123
    - name: SOURCE_ARTIFACT
      value: $(tasks.clone-repository.results.SOURCE_ARTIFACT)
    - name: CHART_CONTEXT
      value: dist/chart/
```

### With image substitution

```yaml
params:
  - name: IMAGE
    value: quay.io/myorg/mychart:on-pr-abc123
  - name: COMMIT_SHA
    value: abc123
  - name: SOURCE_ARTIFACT
    value: $(tasks.clone-repository.results.SOURCE_ARTIFACT)
  - name: IMAGE_MAPPINGS
    value: |
      [
        {
          "source": "localhost/myapp",
          "target": "quay.io/myorg/myapp:on-pr-abc123"
        }
      ]
```

### Preserve Chart.yaml name (0.4)

Set `OVERWRITE_CHART_NAME=false` when multiple components publish the same chart
name to a shared OCI path:

```yaml
params:
  - name: IMAGE
    value: quay.io/myorg/product-chart:on-pr-abc123
  - name: OVERWRITE_CHART_NAME
    value: "false"
```

## Additional info

The `package-and-push` step runs `helm-chart-oci` from the konflux-ci/tools
container image, pinned by digest.

## Source repository for image:

https://github.com/konflux-ci/tools

## Source repository for task:

https://github.com/konflux-ci/tekton-tools
