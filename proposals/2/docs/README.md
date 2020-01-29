## Helmfile and Helm 3 support

This document outlines the new `jx boot` implementation using [helmfile](https://github.com/roboll/helmfile) and helm 3. 

From the outside the use of `jx boot` looks and feels the same both from a user experience and a source code perspective.

## Similarities with `jx boot` and helm 2

Just like classic boot with the [jenkins-x-boot-config](https://github.com/jenkins-x/jenkins-x-boot-config/) git repository, this new [helmfile](https://github.com/roboll/helmfile) solution supports:

* you can run `jx boot` to spin up a new git repository for your development environment
* you can run `jx boot` at any time to reapply changes from your laptop or can trigger a CI/CD pipeline using tekton to do the same thing
* the git repository contains a `jenkins-x.yml` to implement the boot pipeline
* a YAML file is used to store all the charts that are applied using `jx boot`

## Differences with `jx boot` and helm 3

* we use helm 3 along with [helmfile](https://github.com/roboll/helmfile) to actually apply the helm charts into a kubernetes cluster
* any helm chart can be deployed in any namespace (previously we used 1 namespace for all charts in the [env/requirements.yaml](https://github.com/jenkins-x/jenkins-x-boot-config/blob/master/env/requirements.yaml))
* we no longer use a composite chart for `env/Chart.yaml` and instead deploy each chart independently
  * this means that each chart has its own unique version number; so that `helm list` gives nice meaningful results
* we have done away with the complexity of `jenkins-x-platform` (a composite chart containing logs of [dependencies](https://github.com/jenkins-x/jenkins-x-platform/blob/master/jenkins-x-platform/requirements.yaml) like `jenkins` + `chartmuseum` + `nexus` etc) so that each chart can be added/removed independently or swapped out with a different version/distribution
* instead of using [env/requirements.yaml](https://github.com/jenkins-x/jenkins-x-boot-config/blob/master/env/requirements.yaml) we now use a simple and more powerful [jx-apps.yml](https://github.com/jenkins-x-labs/boot-helmfile-poc/blob/master/jx-apps.yml) file which is similar but supports:
  * we can specify a `namespace` on any chart
  * we can add extra `valuesFiles` to use with the chart to override the helm `values.yaml` files
  * different `phase` values so that we can default some charts like `nginx-ingress` to the `system` phase before we setup ingress, DNS, TLS and certs
* instead of copying lots of `env/$appName/values*.yaml` files into the boot config like we do in [these folders](https://github.com/jenkins-x/jenkins-x-boot-config/blob/master/env/) such as [the lighthouse/values.tmpl.yaml](https://github.com/jenkins-x/jenkins-x-boot-config/blob/master/env/lighthouse/values.tmpl.yaml) we can instead default all of these from the version stream at [apps/jenkins-x/lighthouse](https://github.com/jenkins-x/jenkins-x-versions/tree/master/apps/jenkins-x/lighthouse) - which means the boot config git repository is much simpler, we can share more configuration with the version stream and it avoids lots of git merge/rebase issues.
* since we are using helm 3 directly you can add/remove apps and re-run `jx boot` and things are removed correctly.

## Benefits of helmfile and helm 3

* We can use vanilla helm 3 now to install, update or delete charts in any namespace
* It opens the door to a flexible multi-cluster support so that every cluster/environment can be managed in the same canonical GitOps approach
* We can use the `helm list` command line to view versions of each chart/app nicely in the CLI.
* Everything is now an app. So if you want to remove our `nginx-ingress` chart and replace it with another ingress solution (knative / istio / gloo / ambassador / linkerd or whatever) just go ahead and use the [apps commands](apps.md) to add/remove apps.
* The boot git repository is much smaller and simpler; less to keep in sync/rebase/merge with the upstream git repository. Its mostly just 2 YAML files now `jx-requirements.yml` and `jx-apps.yml` which are both pretty much specific to your cluster installation
* We can avoid all the complexities of the `jx step helm apply` logic using our own helm template generation + post processing logic. We can also move away from boot's use of `{{ .Requirements.foo }}` and `{{ .Parameters.bar }}` expressions
* secret handling is currently much simpler - you can provide a `secrets.yaml` file however you want via an environment variable. So ti shoudl be easy to mount secrets from any vault / github secret service / cloud provider service or local file.

## Apps Model

We have enhanced the existing [app extensibility model](apps.md) we have always had with Jenkins X to be more powerful (an app can be in any namespace and can make more use of the [version stream](https://jenkins-x.io/docs/concepts/version-stream/))