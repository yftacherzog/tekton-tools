# build-helm-chart-oci-ta task (0.4)

Packages and pushes a Helm chart to an OCI repository using the `helm-chart-oci`
Go binary from [konflux-ci/tools](https://github.com/konflux-ci/tools).

Version 0.4 replaces the inline bash script from 0.3 with `helm-chart-oci`.
Parameters and results match 0.3, plus optional chart naming control.

## Parameters

| name | description | default value | required |
|---|---|---|---|
| CA_TRUST_CONFIG_MAP_KEY | Key in the CA ConfigMap | ca-bundle.crt | false |
| CA_TRUST_CONFIG_MAP_NAME | CA ConfigMap name | trusted-ca | false |
| CHART_CONTEXT | Path relative to SOURCE_CODE_DIR where the chart lives | dist/chart/ | false |
| COMMIT_SHA | Git commit SHA for version resolution | | true |
| IMAGE_MAPPINGS | JSON array of image mappings | [] | false |
| IMAGE | Full output image reference with tag | | true |
| SOURCE_ARTIFACT | Trusted Artifact URI for application source | | true |
| SOURCE_CODE_DIR | Directory under workingDir with extracted source | source | false |
| TAG_PREFIX | Git tag prefix for version resolution | helm- | false |
| VALUES_FILES | Values files for image substitution | [values.yaml] | false |
| VERSION_SUFFIX | Suffix appended to computed chart version | "" | false |
| CHART_VERSION | Explicit chart version (skips git resolution) | "" | false |
| APP_VERSION | Explicit appVersion override | "" | false |
| OVERWRITE_CHART_NAME | When true, rewrite Chart.yaml name from IMAGE basename (0.3 behavior). When false, preserve Chart.yaml name. | true | false |

## Results

| name | description |
|---|---|
| IMAGE_DIGEST | Digest of the pushed OCI chart artifact |
| IMAGE_URL | Repository and semver tag of the pushed chart |

## Tools image

The `package-and-push` step runs `helm-chart-oci` from the konflux-ci/tools
container image. During development the image is referenced by PR tag; after
release it should be pinned by digest.

## Source repositories

- Task: https://github.com/konflux-ci/tekton-tools
- Tools image: https://github.com/konflux-ci/tools
