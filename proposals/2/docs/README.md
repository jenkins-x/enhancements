## Helmfile and Helm 3 support

This document outlines the new `jx boot` implementation using [helmfile](https://github.com/roboll/helmfile) and helm 3. 

## Getting started

See the [getting started guide](getting-started.md)

## Benefits of helmfile and helm 3

* We can use vanilla helm 3 now to install, update or delete charts in any namespace without needing tiller or custom code to manage `helm template`
  * We can avoid all the complexities of the `jx step helm apply` logic using our own helm template generation + post processing logic. We can also move away from boot's use of `{{ .Requirements.foo }}` and `{{ .Parameters.bar }}` expressions
* It opens the door to a flexible multi-cluster support so that every cluster/environment can be managed in the same canonical GitOps approach (as each cluster can use `jx boot` whether its a dev environment or remote staging/production environment)
* We can use the `helm list` command line to view versions of each chart/app nicely in the CLI.
  * we can avoid composite charts to simplfiy configuration and upgrades
* Everything is now an app. So if you want to remove our `nginx-ingress` chart and replace it with another ingress solution (knative / istio / gloo / ambassador / linkerd or whatever) just go ahead and use the [apps commands](apps.md) to add/remove apps and have boot manage everything in a consistent way
* The boot git repository is much smaller and simpler; less to keep in sync/rebase/merge with the upstream git repository. Its mostly just 2 YAML files now `jx-requirements.yml` and `jx-apps.yml` which are both pretty much specific to your cluster installation and a shared `jenkins-x.yml` file (which over time we can move into the build pack).
  * we rely more instead on the [version stream](https://jenkins-x.io/docs/concepts/version-stream/) which can be shared across installations
* secret handling is currently much simpler - you can provide a `secrets.yaml` file however you want via an environment variable. So it should be easy to mount secrets from any vault / github secret service / cloud provider service or local file.
  * we've moved population of the secrets outside of the boot process so we should be able to default to running `jx boot` via a helm chart to simplify installation and avoid issues with local laptop configuration + binary packaeg differences.

## Comparison

Here is a [comparison of boot with helmfile and helm 3](comparison.md) in terms of similarities and differences if you are already aware of `jx boot` with helm 2.

## Apps Model

We have enhanced the existing [app extensibility model](apps.md) we have always had with Jenkins X to be more powerful:
* an app can be in any namespace and can make more use of the [version stream](https://jenkins-x.io/docs/concepts/version-stream/))
* everything is now an app including the system charts like `nginx-ingress` and `cert-manager`

## Tips and tricks

For those new to helmfile and helm there we have some [tips and tricks](tips.md)

## How it works

Here is [how boot works with helmfile and helm 3](how-it-works.md) if you want to understand how the implementation works.


