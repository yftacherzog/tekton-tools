# rpms-signature-scan task

Scans RPMs in an image and provide information about RPMs signatures.

## Parameters
|name|description|default value|required|
|---|---|---|---|
|image-url|Image URL||true|
|image-digest|Image digest to scan||true|
|workdir|Directory that will be used for storing temporary files produced by this task. |/tmp|false|
|ca-trust-config-map-name|The name of the ConfigMap to read CA bundle data from.|trusted-ca|false|
|ca-trust-config-map-key|The name of the key in the ConfigMap that contains the CA bundle data.|ca-bundle.crt|false|

## Results
|name|description|
|---|---|
|TEST_OUTPUT|Tekton task test output.|
|RPMS_DATA|Information about signed and unsigned RPMs|
|IMAGES_PROCESSED|Images processed in the task.|
|SCAN_LOG|Diagnostic log from the RPM scan (e.g. selective extraction info).|


## Additional info

The RPM's signature keys as well as the unsigned RPMs are saved into the `RPMS_DATA`
result path and they are processed by Conforma to determine whether the task should fail
or not.

The task will fail in case one or more images have failed the scan.

### ModelCar / OLOT image support

The task automatically detects ModelCar images built with
[OLOT](https://github.com/containers/olot) (OCI Layers On Top). Layers annotated
with `olot.layer.content.*` are skipped during RPM database extraction, avoiding
unnecessary I/O on large model-data layers. Regular images are unaffected.

## Source repository for image:

https://github.com/konflux-ci/tools

## Source repository for task:

https://github.com/konflux-ci/tekton-tools
