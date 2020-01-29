## Apps framework

The new [helmfile](https://github.com/roboll/helmfile) and helm 3 approach extends the app extension model in Jenkins X.

In essence that means if you are using helmfile you can use the usual Apps commands which create Pull Requests on the [jx-apps.yml](https://github.com/jenkins-x-labs/boot-helmfile-poc/blob/master/jx-apps.yml) file in your environments git repository rather than the traditional `env/requirements.yaml` file.

This also means you can have apps in different namespaces. e.g. its common to put some charts in different namespaces like `nginx-ingress`, `gloo`, `cert-mangager` etc.

### Using the apps commands

you can use [jx add app](https://jenkins-x.io/commands/jx_add_app/) to add apps using the usual helm style notation of `repositoryPrefix/chartName` such as:

```
jx add app jetstack/cert-manager
jx add app flagger/flagger

```

these commands will implicity use the [version stream](https://jenkins-x.io/docs/concepts/version-stream/) configuration (via [charts/repositories.yml](https://github.com/jenkins-x/jenkins-x-versions/blob/master/charts/repositories.yml)) to determine the mapping of prefixes to repository URLs.

Then these commands will create Pull Requests on the [jx-apps.yml](https://github.com/jenkins-x-labs/boot-helmfile-poc/blob/master/jx-apps.yml) file in your environments git repository.

Note that usually the Pull Request will only add a simple line of the format to the `applications:` entry:

```
applications:
- name: jetstack/cert-manager 
- name: flagger/flagger
``` 

This keeps the configuration in the environment git repository nice and concise. The `version` of the chart is then resolved during deployment via the [version stream](https://jenkins-x.io/docs/concepts/version-stream/).

### Viewing apps

You can view your apps across all namespaces via [jx get app](https://jenkins-x.io/commands/jx_get_apps/)

``` 
jx get app
```

This will effectively display data from the [jx-apps.yml](https://github.com/jenkins-x-labs/boot-helmfile-poc/blob/master/jx-apps.yml). This data will be pretty close to using a regular `helm list` using helm 3.x or later; only it will show apps across all namespaces by default..

