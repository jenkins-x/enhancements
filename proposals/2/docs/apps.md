## Apps framework

The new [helmfile](https://github.com/roboll/helmfile) and helm 3 approach extends the app extension model in Jenkins X.

In essence that means if you are using helmfile you can use the usual Apps commands which create Pull Requests on the [jx-apps.yml](https://github.com/jenkins-x-labs/boot-helmfile-poc/blob/master/jx-apps.yml) file in your environments git repository rather than the traditional `env/requirements.yaml` file.

This also means you can have apps in different namespaces. e.g. its common to put some charts in different namespaces like `nginx-ingress`, `gloo`, `cert-mangager` etc.

### Using the apps commands

you can use `jx add app` to add apps using the usual helm style notation of `repositoryPrefix/chartName` such as:

```
jx add app jetstack/cert-manager
jx add app flagger/flagger

```

these commands will implicity use the [version stream]() configuration (via [charts/repositories.yml]()) to determine the mapping of prefixes to repository URLs.

