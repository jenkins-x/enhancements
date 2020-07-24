---
title: Preview with Helmfile
linktitle: Preview with Helmfile
description: Preview with Helmfile
type: docs
weight: 40
---

# JX Enhancement 4: Preview with Helmfile

## 1. Overview

This document outlines the work for deploying [Jenkins X Preview Environments](https://jenkins-x.io/docs/reference/preview/) using [Helmfile](https://github.com/roboll/helmfile) - instead of raw [Helm](https://helm.sh/) - and the benefits. 

### 1.1 Motivation

Preview Environments are currently (April 2020) implemented using an "umbrella (Helm) chart", named `preview`, located in the `charts/preview` directory of applications repositories.
This umbrella chart usually has no templates, just a dependency on the "main" application chart, and maybe on some other charts. Values for the main application can be customized by using the `values.yaml` file of the preview chart.

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

There is already work being done to re-implement the staging/prod charts installation, using [Helmfile](https://github.com/roboll/helmfile), which would also bring in Helm 3 support. 
This work might also be used for the "jx boot" part.

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

The `charts/preview` directory won't be a Helm chart anymore, but an Helmfile project. 
And instead of using raw Helm commands to deploy the preview, jx will use Helmfile commands.

The only required file in this folder is `the helmfile.yaml` - which defines all the releases we want to install.
```yaml
# https://github.com/roboll/helmfile

# we can use Helm 3 if its present in the container image
helmBinary: helm3

helmDefaults:
  wait: true
  timeout: 180 # seconds

# extra Helm repositories
repositories:
  - name: bitnami
    url: https://charts.bitnami.com/bitnami
  - name: something-else
    url: http://charts.example.com

# all the releases we want to install in a preview env
releases:

  - # the main application's chart
    name: {{ .Values.preview.releaseName }}
    namespace: {{ .Values.preview.namespace }}
    chart: ../{{ requiredEnv "APP_NAME" }}
    values:
      - values.yaml.gotmpl

  - # we can include other releases as well
    name: postgresql
    namespace: 
    chart: bitnami/postgresql
    version: 8.9.2
    values:
      - postgresql.yaml
``` 
Custom values can either be written directly in this file, or in other files - such as values.yaml.gotmpl - which are defined in the main `helmfile.yaml`.
```go-text-template
# This file contains the custom values for our application's chart
# and support Go templates, parsed by https://github.com/roboll/helmfile

image:
  repository: {{ .Values.preview.image.repository }}
  tag: {{ .Values.preview.image.tag }}

ingress:
  enabled: true
  class: nginx
  hosts:
    - '{{ .values.preview.name }}.{{ .Values.expose.config.domain }}'
  tls:
    enabled: true
    secrets:
      wildcard:
        replicateFrom: {{ requiredEnv "WILDCARD_TLS_SECRET_LOCATION" }}

labels:
  git-commit: {{ requiredEnv "PULL_PULL_SHA" }}

```

The `jx preview` command will have to be modified to execute the `helmfile apply` command on this directory. This command will take care of:
- adding required Helm repositories
- calculates the "diff" of what needs to be done, and print it
- apply the diff

We will also need to pass some values calculated by Jenkins X - such as the `extraValues.yaml` generated for Helm. The same file can also be passed to Helmfile, using the `--state-values-file` flag.

### 2.3 Implementation

#### 2.3.1 Quick and dirty implementation

I already have a working implementation which we are already using at Dailymotion.
It's just a quick and dirty implementation that works for our use-case, so it will need more work to handle more use-cases.

It is in the [preview-helmfile branch](https://github.com/vbehar/jx/tree/preview-helmfile), and you can see the [diff with jx master](https://github.com/jenkins-x/jx/compare/master...vbehar:preview-helmfile).

A few notes:
- it is based on v2.0.1245 because we are using CJXD 8
- I've updated the `extraValues.yaml` file to include:
  - `name` of the preview
  - `releaseName` of the preview
  - `namespace` of the preview
- the `jx preview` command has a new `--helmfile` flag to give it the name of a helmfile.yaml
- the `helmfile` command being used is `helmfile --file=helmfile.yaml --state-values-file=extraValues.yaml --state-values-set=tags.jx-ns-NAMESPACE=true,global.jxNsNAMESPACE=true,...,global.jxNs=NAMESPACE,... --namespace=NAMESPACE apply`

We call it with the following flags: `jx preview --app "${APP_NAME}" --namespace "preview-${APP_NAME}-pr-${PULL_NUMBER}" --name "preview-${APP_NAME}-pr-${PULL_NUMBER}" --release "preview-${APP_NAME}-pr-${PULL_NUMBER}" --helmfile "helmfile.yaml" --verbose` - see  the jenkins-x.yml below for the jx pipeline.
```yaml
buildPack: none
pipelineConfig:
  pipelines:
    pullRequest:
      pipeline:
        stages:
          - name: preview-env
            steps:
              - name: deploy-preview-env
                command: jx preview
                args:
                  - --app "${APP_NAME}"
                  - --namespace "preview-${APP_NAME}-pr-${PULL_NUMBER}"
                  - --name "preview-${APP_NAME}-pr-${PULL_NUMBER}"
                  - --release "preview-${APP_NAME}-pr-${PULL_NUMBER}"
                  - --helmfile "helmfile.yaml"
                  - --verbose
                dir: charts/preview
                image: our-custom-jx-image-with-helmfile
                env:
                  - name: WILDCARD_TLS_SECRET_LOCATION
                    value: jx/tls-jx-example-com-p
```

The `--app` flag is "mandatory" when using helmfile, to avoid trying to find a default value from the preview chart, which doesn't exist anymore.

The `jx preview` command is now run in a specific container image, which contains:
- `jx` built from the [preview-helmfile branch](https://github.com/vbehar/jx/tree/preview-helmfile)
- `helmfile` version 0.111.0 - it needs a recent version to support the `helmBinary` config flag
- `helm3` binary, we used version 3.2.0
- a few Helm plugins
see the Dockerfile below for more details. This image has both `helm` and `helm3` binaries. We might have plugins compatibility issues. 
For now in this quick-and-dirty implementation we ignored this issue, because this image is only used to run `jx preview` with helmfile and helm 3, so it never uses Helm 2.

```docker
# part of the Dockerfile used to build the container image used to run "jx preview" with helmfile

# install helm
ENV HELM_VERSION 2.14.2
ENV HELM_HOME "/helm"
RUN echo "Installing Helm ${HELM_VERSION}" \
 && curl -f https://storage.googleapis.com/kubernetes-helm/helm-v${HELM_VERSION}-linux-amd64.tar.gz | tar xzv \
 && mv linux-amd64/helm /usr/bin/ \
 && mv linux-amd64/tiller /usr/bin/ \
 && rm -rf linux-amd64 \
 && helm init --client-only

ENV HELM3_VERSION="3.2.0"
RUN echo "Installing Helm3 ${HELM3_VERSION}" \
 && curl -f https://get.helm.sh/helm-v${HELM3_VERSION}-linux-amd64.tar.gz | tar xzv \
 && mv linux-amd64/helm /usr/bin/helm3 \
 && rm -rf linux-amd64

ENV HELM_PLUGINS="/helm/plugins"
RUN echo "Installing Helm3 plugins in ${HELM_PLUGINS}" \
 && export XDG_DATA_HOME="/" \
 && helm3 plugin install https://github.com/futuresimple/helm-secrets --version v2.0.2 \
 && helm3 plugin install https://github.com/databus23/helm-diff --version v3.1.1 \
 && helm3 plugin install https://github.com/hayorov/helm-gcs --version 0.3.1 \
 && unset XDG_DATA_HOME

ENV HELMFILE_VERSION 0.111.0
RUN echo "Installing helmfile ${HELMFILE_VERSION}" \
 && curl -LO https://github.com/roboll/helmfile/releases/download/v${HELMFILE_VERSION}/helmfile_linux_amd64 \
 && chmod +x helmfile_linux_amd64 \
 && mv helmfile_linux_amd64 /usr/bin/helmfile

# install kubectl
ENV KUBECTL_VERSION="1.15"
RUN echo "Installing kubectl ${KUBECTL_VERSION}" \
 && curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable-${KUBECTL_VERSION}.txt)/bin/linux/amd64/kubectl \
 && chmod +x kubectl \
 && mv kubectl /usr/bin/
```

You can see the output:
- for the first run
```plaintext
Creating a preview
expose:
  Annotations:
    helm.sh/hook: post-install,post-upgrade
    helm.sh/hook-delete-policy: hook-succeeded
  config:
    domain: jx.example.com
    exposer: Ingress
    http: "true"
preview:
  image:
    repository: gcr.io/owner/myapp
    tag: 0.0.0-SNAPSHOT-PR-129-16
  name: preview-myapp-pr-129
  namespace: preview-myapp-pr-129
  releaseName: preview-myapp-pr-129
Installing Preview Environment with Helmfile...
Running: helmfile --file=helmfile.yaml --state-values-file=/workspace/source/charts/preview/extraValues.yaml --state-values-set=tags.jx-ns-preview-myapp-pr-129=true,global.jxNsPreviewMyappPr129=true,tags.jx-preview=true,tags.jx-env-preview-myapp-pr-129=true,global.jxPreview=true,global.jxEnvPreviewMyappPr129=true,global.jxNs=preview-myapp-pr-129,global.jxTypeEnv=preview,global.jxEnv=preview-myapp-pr-129,global.jxPreviewApp=myapp,global.jxPreviewPr=129 --namespace=preview-myapp-pr-129 apply
Building dependency release=preview-myapp-pr-129, chart=../myapp
Comparing release=preview-myapp-pr-129, chart=../myapp
********************

	Release was not present in Helm.  Diff will show entire contents as new.

********************
preview-myapp-pr-129, preview-myapp-pr-129-tls-wildcard, Secret (v1) has been added:
+ # Source: myapp/templates/ingress.yaml
+ apiVersion: v1
+ kind: Secret
+ metadata:
+   annotations:
+     replicator.v1.mittwald.de/replicate-from: jx/tls-jx-example-com-p
+   labels:
+     app.kubernetes.io/instance: preview-myapp-pr-129
+     app.kubernetes.io/managed-by: Helm
+     app.kubernetes.io/name: myapp
+     app.kubernetes.io/version: latest
+     git-commit: 94f909b03f2f4189ac433e1aba8cd1147b3aa467
+     helm.sh/chart: myapp-4.3.0
+   name: preview-myapp-pr-129-tls-wildcard
+ data:
+   tls.crt: '++++++++ # (0 bytes)'
+   tls.key: '++++++++ # (0 bytes)'
+ type: kubernetes.io/tls

preview-myapp-pr-129, preview-myapp-pr-129, Service (v1) has been added:
-
+ # Source: myapp/templates/service.yaml
+ apiVersion: v1
+ kind: Service
+ metadata:
+   name: preview-myapp-pr-129
+   labels:
+     helm.sh/chart: myapp-4.3.0
+     app.kubernetes.io/name: myapp
+     app.kubernetes.io/instance: preview-myapp-pr-129
+     app.kubernetes.io/version: "latest"
+     app.kubernetes.io/managed-by: Helm
+     git-commit: 94f909b03f2f4189ac433e1aba8cd1147b3aa467
+ spec:
+   type: ClusterIP
+   ports:
+     - name: http
+       port: 8080
+       targetPort: http
+   selector:
+     app.kubernetes.io/name: myapp
+     app.kubernetes.io/instance: preview-myapp-pr-129
preview-myapp-pr-129, preview-myapp-pr-129, Deployment (apps) has been added:
-
+ # Source: myapp/templates/deployment.yaml
+ apiVersion: apps/v1
+ kind: Deployment
+ metadata:
+   name: preview-myapp-pr-129
+   labels:
+     helm.sh/chart: myapp-4.3.0
+     app.kubernetes.io/name: myapp
+     app.kubernetes.io/instance: preview-myapp-pr-129
+     app.kubernetes.io/version: "latest"
+     app.kubernetes.io/managed-by: Helm
+     git-commit: 94f909b03f2f4189ac433e1aba8cd1147b3aa467
+ spec:
+   replicas: 1
+   revisionHistoryLimit: 2
+   selector:
+     matchLabels:
+       app.kubernetes.io/name: myapp
+       app.kubernetes.io/instance: preview-myapp-pr-129
+   template:
+     metadata:
+       labels:
+         helm.sh/chart: myapp-4.3.0
+         app.kubernetes.io/name: myapp
+         app.kubernetes.io/instance: preview-myapp-pr-129
+         app.kubernetes.io/version: "latest"
+         app.kubernetes.io/managed-by: Helm
+         git-commit: 94f909b03f2f4189ac433e1aba8cd1147b3aa467
+     spec:
+       containers:
+         - name: myapp
+           image: "gcr.io/owner/myapp:0.0.0-SNAPSHOT-PR-129-16"
+           ports:
+             - name: http
+               containerPort: 8080
+           livenessProbe:
+             tcpSocket:
+               port: http
+           readinessProbe:
+             httpGet:
+               path: /
+               port: http
+           resources:
+             limits:
+               cpu: "0.1"
+               memory: 32M
+             requests:
+               cpu: "0.1"
+               memory: 32M
+       enableServiceLinks: false
+       terminationGracePeriodSeconds: 30
preview-myapp-pr-129, preview-myapp-pr-129, Ingress (networking.k8s.io) has been added:
-
+ # Source: myapp/templates/ingress.yaml
+ apiVersion: networking.k8s.io/v1beta1
+ kind: Ingress
+ metadata:
+   name: preview-myapp-pr-129
+   labels:
+     helm.sh/chart: myapp-4.3.0
+     app.kubernetes.io/name: myapp
+     app.kubernetes.io/instance: preview-myapp-pr-129
+     app.kubernetes.io/version: "latest"
+     app.kubernetes.io/managed-by: Helm
+     git-commit: 94f909b03f2f4189ac433e1aba8cd1147b3aa467
+   annotations:
+     kubernetes.io/ingress.class: nginx
+     kubernetes.io/ingress.allow-http: "false"
+ spec:
+   rules:
+     - host: preview-myapp-pr-129.jx.example.com
+       http:
+         paths:
+           - backend:
+               serviceName: preview-myapp-pr-129
+               servicePort: 8080
+   tls:
+     - secretName: preview-myapp-pr-129-tls-wildcard

Upgrading release=preview-myapp-pr-129, chart=../myapp
Release "preview-myapp-pr-129" does not exist. Installing it now.
NAME: preview-myapp-pr-129
LAST DEPLOYED: Fri Apr 24 05:11:49 2020
NAMESPACE: preview-myapp-pr-129
STATUS: deployed
REVISION: 1

Listing releases matching ^preview-myapp-pr-129$
preview-myapp-pr-129	preview-myapp-pr-129	1       	2020-04-24 05:11:49.634624822 +0000 UTC	deployed	myapp-4.3.0	latest


UPDATED RELEASES:
NAME                          CHART             VERSION
preview-myapp-pr-129   ../myapp     4.3.0

Preview Environment successfully installed with Helmfile!
```
- for the second run
```plaintext
Creating a preview
expose:
  Annotations:
    helm.sh/hook: post-install,post-upgrade
    helm.sh/hook-delete-policy: hook-succeeded
  config:
    domain: jx.example.com
    exposer: Ingress
    http: "true"
preview:
  image:
    repository: gcr.io/owner/myapp
    tag: 0.0.0-SNAPSHOT-PR-129-18
  name: preview-myapp-pr-129
  namespace: preview-myapp-pr-129
  releaseName: preview-myapp-pr-129
Installing Preview Environment with Helmfile...
Running: helmfile --file=helmfile.yaml --state-values-file=/workspace/source/charts/preview/extraValues.yaml --state-values-set=tags.jx-ns-preview-myapp-pr-129=true,global.jxNsPreviewMyappPr129=true,tags.jx-preview=true,tags.jx-env-preview-myapp-pr-129=true,global.jxPreview=true,global.jxEnvPreviewMyappPr129=true,global.jxNs=preview-myapp-pr-129,global.jxTypeEnv=preview,global.jxEnv=preview-myapp-pr-129,global.jxPreviewApp=myapp,global.jxPreviewPr=129 --namespace=preview-myapp-pr-129 apply
Building dependency release=preview-myapp-pr-129, chart=../myapp
Comparing release=preview-myapp-pr-129, chart=../myapp
preview-myapp-pr-129, preview-myapp-pr-129, Deployment (apps) has changed:
  # Source: myapp/templates/deployment.yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: preview-myapp-pr-129
    labels:
      helm.sh/chart: myapp-4.3.0
      app.kubernetes.io/name: myapp
      app.kubernetes.io/instance: preview-myapp-pr-129
      app.kubernetes.io/version: "latest"
      app.kubernetes.io/managed-by: Helm
      git-commit: 94f909b03f2f4189ac433e1aba8cd1147b3aa467
  spec:
    replicas: 1
    revisionHistoryLimit: 2
    selector:
      matchLabels:
        app.kubernetes.io/name: myapp
        app.kubernetes.io/instance: preview-myapp-pr-129
    template:
      metadata:
        labels:
          helm.sh/chart: myapp-4.3.0
          app.kubernetes.io/name: myapp
          app.kubernetes.io/instance: preview-myapp-pr-129
          app.kubernetes.io/version: "latest"
          app.kubernetes.io/managed-by: Helm
          git-commit: 94f909b03f2f4189ac433e1aba8cd1147b3aa467
      spec:
        containers:
          - name: myapp
-           image: "gcr.io/owner/myapp:0.0.0-SNAPSHOT-PR-129-16"
+           image: "gcr.io/owner/myapp:0.0.0-SNAPSHOT-PR-129-18"
            ports:
              - name: http
                containerPort: 8080
            livenessProbe:
              tcpSocket:
                port: http
            readinessProbe:
              httpGet:
                path: /
                port: http
            resources:
              limits:
                cpu: "0.1"
                memory: 32M
              requests:
                cpu: "0.1"
                memory: 32M
        enableServiceLinks: false
        terminationGracePeriodSeconds: 30

Upgrading release=preview-myapp-pr-129, chart=../myapp
Release "preview-myapp-pr-129" has been upgraded. Happy Helming!
Listing releases matching ^preview-myapp-pr-129$
NAME: preview-myapp-pr-129
LAST DEPLOYED: Fri Apr 24 08:36:04 2020
NAMESPACE: preview-myapp-pr-129
STATUS: deployed
REVISION: 2

preview-myapp-pr-129	preview-myapp-pr-129	2       	2020-04-24 08:36:04.231316767 +0000 UTC	deployed	myapp-4.3.0	latest


UPDATED RELEASES:
NAME                          CHART             VERSION
preview-myapp-pr-129   ../myapp     4.3.0

Preview Environment successfully installed with Helmfile!
```

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

It is a relatively small change but with a big impact, because it will impact the organization of all repositories using Jenkins X.
Here is a migration plan proposal:

1. Use a new "alpha" command to allow a few users to try out this new feature, without impacting other users.
This would still require a change in the container image, to bundle Helmfile and Helm 3 along with jx and Helm 2.
1. Use an auto-detection mechanism to see if the `charts/preview` directory contains a `Chart.yaml` or an `helmfile.yaml` file, and use the right tool - Helm or Helmfile - based on that.
This would allow users to migrate their repositories one by one.
1. Update the buildpacks to generate the `charts/preview` with an `helmfile.yaml` file instead of an "umbrella" chart.
At this point new repositories will use Helmfile by default.
1. Write a migration tool / command to migrate from an umbrella chart to an Helmfile structure?
1. Deprecate the support for the umbrella chart: when we detect a `Chart.yaml` print a warning message in the logs.
1. Remove support for the umbrella chart.
