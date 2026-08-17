# Tekton Tools

Tekton tasks and pipeline used by AppStudio.


## Installation

Requires a cluster with the Tekton Task CRD and `kubectl`. Apply the actively
maintained task:

```bash
kubectl apply -f tasks/rpms-signature-scan/0.2/rpms-signature-scan.yaml -n <namespace>
```

## Usage

Task parameters and results are documented in each version directory's `README.md`
(for example [`tasks/rpms-signature-scan/0.2/README.md`](tasks/rpms-signature-scan/0.2/README.md)).
How CI runs the task against sample images: [AGENTS.md](AGENTS.md) (CI / Testing) and `.tekton/rpms-signature-scan-tests-pull-request.yaml`.

## Kerberos keytab

Generating composes with ODCS requires a Kerberos keytab for authentication. The
keytab should be provided as a secret on the namespace where the task is running and
requires the Kerberos cache to be refreshed and held in a single place and shared
between consecutive runs of the task (to overcome potential conflicts between multiple
kerberos sessions).

For that, we need to:
1. Create a secret for the Kerberos keytab.
2. Use a cronjob to maintain another secret for the Kerberos cache that will be used
   by all tasks that require Kerberos authentication.

### Creating the keytab secret

Save the keytab in a file called `keytab` and use the command below to generate the secret:

```
oc create secret generic --from-file <path-to-keytab-file>/keytab --dry-run=client -o yaml rhtap-compose > rhtap-compose-secret.yaml
```

Make sure that the field inside the `data` field within the generated YAML is called
`keytab`, as this is what the conrjob is expecting to find.

Finally, apply the configurations in rhtap-compose-secret.yaml to the namespace in which
the tasks should run.

### Creating the cronjob

To create the cronjob and its required service account, role and role binding, apply
the [configs](config/cache-cronjob.yaml) to the namespace where the task needs to run.

## Development

See [AGENTS.md](AGENTS.md) for linting, CI, and how to add or update tasks.

```bash
pipenv sync --dev
pipenv run yamllint .
```
