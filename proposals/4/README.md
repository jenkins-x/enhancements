
# JX Enhancement 4: Preview with Helmfile

## 1. Overview

This document outlines the work for deploying [Jenkins X Preview Environments](https://jenkins-x.io/docs/reference/preview/) using [Helmfile](https://github.com/roboll/helmfile) - instead of raw [Helm](https://helm.sh/) - and the benefits. 

### 1.1 Motivation

Preview Environments are currently (April 2020) implemented using an "umbrella (Helm) chart", named `preview`, located in the `charts/preview` directory of applications repositories. This umbrella chart usually has no templates, just a dependency on the "main" application chart, and maybe on some other charts. Values for the main application can be customized by using the `values.yaml` file of the preview chart.

This implementation works, but has a number of limitations:
- no templating of the preview's `values.yaml` - the workaround is to use Helm's `tpl` function in the main chart's templates when using values customized by the preview chart.
- no easy way to use an environment variable in the values, although it's very easy to add some in the pipeline
- the preview chart needs to be hacked before being used, this is done with a [Makefile](https://github.com/jenkins-x-buildpacks/jenkins-x-kubernetes/blob/master/packs/go/preview/Makefile) which uses `sed` commands to replace values in the `Chart.yaml` and `values.yaml` files, and this `Makefile` can quickly grow if people re-use this hack as a workaround the templating limitations.
- adding new charts dependencies in a preview environment can easily be done by updating the `requirements.yaml` file... as long as you respect the [strict formatting rules of this file](https://github.com/jenkins-x-buildpacks/jenkins-x-kubernetes/blob/master/packs/go/preview/requirements.yaml), and you don't need charts from a specific repository. Otherwise, you'll need to update the `Makefile` to add your repositories first.
- the `values.yaml` file is confusing for newcomers, because the values for the main chart are placed under the `preview` definition - because the main chart is aliased as `preview`.
- `jx` uses the same Helm settings to deploy its own charts and the preview charts. So by default its Helm 2 in templating mode. Which makes it harder to debug a preview environment, because in templating mode we don't store the Helm release secret with the values.
- another issue with Helm 2 in templating mode is the limited support for Helm hooks - which have been re-implmented in Jenkins X.

### 1.2 Background

Helm is currently used by Jenkins X to:
- deploy its own components / charts: prow/lighthouse, tekton, controllers, ...
- deploy the preview environments - in the pullrequest pipelines
- package the application's chart - in the release pipeline
- install the applications in the staging/prod environments

There is already work being done to re-implement the staging/prod charts installation, using [Helmfile](https://github.com/roboll/helmfile), which would also bring in Helm 3 support. This work might also be used for the "jx boot" part.

So it means there are 2 "direct" use of Helm left: the previews and the chart packaging. This proposal is focused on the previews use-case, and coherent with what is being done in other parts of Jenkins X.

## 2. Proposal

### 2.1 Helmfile

Why [Helmfile](https://github.com/roboll/helmfile)?
- already being integrated in Jenkins X
- some Jenkins X users (Dailymotion) have experience using it to deploy applications in (remote) staging/prod environments
- support templated values files
- support secrets from various backends: [sops](https://github.com/mozilla/sops), [Vault](https://www.vaultproject.io/), ... - see [github.com/variantdev/vals](https://github.com/variantdev/vals) which is used by Helmfile
- declarative definition of the releases of course, but also the Helm repositories and the Helm settings: timeout, force, wait, ...
- supports Helm 2 with or without Tiller, and Helm 3
- lots of features, including
  - hooks
  - nested helmfile, which can be remote files using the Terraform-module-like URL: `git::https://github.com/jenkins-x-buildpacks/jenkins-x-kubernetes.git@packs/go/helmfile.yaml?ref=0.40.0`
- written in Go
- actively developed and growing usage - used for Jenkins's own infrastructure for example

### 2.2 Design

The `charts/preview` directory won't be a Helm chart anymore, but an Helmfile project. And instead of using raw Helm commands to deploy the preview, jx will use Helmfile commands.

The only required file in this folder is [helmfile.yaml](helmfile.yaml) - which defines all the releases we want to install. Custom values can either be written directly in this file, or in other files - such as [values.yaml.gotmpl](values.yaml.gotmpl) - which are defined in the main `helmfile.yaml`. 

The `jx preview` command will have to be modified to execute the `helmfile apply` command on this directory. This command will take care of:
- adding required Helm repositories
- calculates the "diff" of what needs to be done, and print it
- apply the diff

We will also need to pass some values calculated by Jenkins X - such as the `extraValues.yaml` generated for Helm. The same file can also be passed to Helmfile, using the `--state-values-file` flag.

### 2.3 Implementation

#### 2.3.1 Quick and dirty implementation

I already have a working implementation which we are already using at Dailymotion. It's just a quick and dirty implementation that works for our use-case, so it will need more work to handle more use-cases.

It is in the [preview-helmfile branch](https://github.com/vbehar/jx/tree/preview-helmfile), and you can see the [diff with jx master](https://github.com/jenkins-x/jx/compare/master...vbehar:preview-helmfile).

A few notes:
- it is based on v2.0.1245 because we are using CJXD 8
- I've updated the `extraValues.yaml` file to include:
  - `name` of the preview
  - `releaseName` of the preview
  - `namespace` of the preview
- the `jx preview` command has a new `--helmfile` flag to give it the name of a helmfile.yaml
- the `helmfile` command being used is `helmfile --file=helmfile.yaml --state-values-file=extraValues.yaml --state-values-set=tags.jx-ns-NAMESPACE=true,global.jxNsNAMESPACE=true,...,global.jxNs=NAMESPACE,... --namespace=NAMESPACE apply`

We call it with the following flags: `jx preview --app "${APP_NAME}" --namespace "preview-${APP_NAME}-pr-${PULL_NUMBER}" --name "preview-${APP_NAME}-pr-${PULL_NUMBER}" --release "preview-${APP_NAME}-pr-${PULL_NUMBER}" --helmfile "helmfile.yaml" --verbose` - see [jenkins-x.yml](jenkins-x.yml) for the jx pipeline.

The `--app` flag is "mandatory" when using helmfile, to avoid trying to find a default value from the preview chart, which doesn't exist anymore.

The `jx preview` command is now run in a specific container image, which contains:
- `jx` built from the [preview-helmfile branch](https://github.com/vbehar/jx/tree/preview-helmfile)
- `helmfile` version 0.111.0 - it needs a recent version to support the `helmBinary` config flag
- `helm3` binary, we used version 3.2.0
- a few Helm plugins
see the [Dockerfile](Dockerfile) for more details. This image has both `helm` and `helm3` binaries. We might have plugins compatibility issues. For now in this quick-and-dirty implementation we ignored this issue, because this image is only used to run `jx preview` with helmfile and helm 3, so it never uses Helm 2.

You can see the output:
- [for the first run](output-1.txt)
- [for the second run](output-2.txt)

#### 2.3.3 Proposed implementation

The real implementation should:
- include a recent version of helmfile and helm 3 in the official jx container image, along with helmfile's required plugins (diff)
- use a global flag in `jx-requirements.yaml` to enable Helmfile for preview environment
- don't fail if it doesn't find a preview chart
- maybe generate a `helmfile.yaml` with good default values if none can be found in the repository?

## 3. Benefits

There are quite a few benefits:

- very easy to add charts in a preview env, including ones from custom repos
- values files can now be templatized, using (almost) the same functions as Helm templates
- can use secrets from multiple backends, including [sops](https://github.com/mozilla/sops)
- using Helm 3, which brings support for library charts - but it can also use Helm 2, in tiller-less mode

## 4. Migration

It is a relatively small change but with a big impact, because it will impact the organization of all repositories using Jenkins X. Here is a migration plan proposal:

1. Use a new "alpha" command to allow a few users to try out this new feature, without impacting other users. This would still require a change in the container image, to bundle Helmfile and Helm 3 along with jx and Helm 2.
1. Use an auto-detection mechanism to see if the `charts/preview` directory contains a `Chart.yaml` or an `helmfile.yaml` file, and use the right tool - Helm or Helmfile - based on that. This would allow users to migrate their repositories one by one.
1. Update the buildpacks to generate the `charts/preview` with an `helmfile.yaml` file instead of an "umbrella" chart. At this point new repositories will use Helmfile by default.
1. Write a migration tool / command to migrate from an umbrella chart to an Helmfile structure?
1. Deprecate the support for the umbrella chart: when we detect a `Chart.yaml` print a warning message in the logs.
1. Remove support for the umbrella chart.
