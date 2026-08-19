# Migration from 0.1 to 0.2
The parameter `fail-unsigned` used by `rpms-signature-scan` task was removed.

## Action from users
Remove the `fail-unsigned` parameter from the `rpms-signature-scan` task in your pipeline.


# Migration from 0.2 to 0.2.1
Updating image repository from `konflux-vanguard` to `tekton-catalog`

## Action from users
None - Migration script should handle it


# Migration from 0.2.1 to 0.2.2
Updated tools image with selective layer extraction for ModelCar (OLOT) images.
The task now detects layers annotated with `olot.layer.content.*` and skips them
during RPM database extraction, avoiding unnecessary I/O on large model-data layers.

## Action from users
None - No breaking changes. Regular images are unaffected. ModelCar images are
handled automatically.
