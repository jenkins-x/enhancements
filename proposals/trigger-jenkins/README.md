---
title: Trigger Jenkins
linktitle: Trigger Jenkins
description: Trigger Jenkins Pipelines from Jenkins X and Tekton
weight: 70
---

# Problem: be able to trigger pipelines in remote Jenkins servers

We want to make it easy to reuse existing remote Jenkins servers with Jenkins X / tekton so that folks can work with either 100% cloud native tekton based automated CI/CD from Jenkins X or reuse existing Jenkins pipelines with remote Jenkins servers.

Over time we can then bring more value to folks using a mixture of Jenkins + Jenkins X. e.g.

*   Reuse ChatOps from Jenkins X for existing projects that use Jenkins pipelines
*   Reuse Jenkins X Apps / Build Packs on projects released by Jenkins
    *   E.g. reuse Jenkins X Apps / Pipelines for linting, code quality, security scanning - while preserving the existing Jenkins pipelines


## Solutio

Check out the [docs for using the PoC and using it with Jenkins X and helm 3](https://jenkins-x.io/docs/labs/jenkins/)

In addition there is a small CLI / container image [jenkins-x-labs/trigger-pipeline](https://github.com/jenkins-x-labs/trigger-pipeline) which can be invoked from inside any kind of CI / pipeline to trigger a pipeline in a remote Jenkins server.

This allows a jenkins pipeline to be invoked in:

*   any kubernetes cluster/namespace
*   any jenkins server (inside or outside of k8s)

from anywhere in the cloud native ecosystem:

*   Kubernetes Job
*   Jenkins X Pipeline
*   Tekton
*   GitHub Actions
*   Any Jenkins server (inside or outside of k8s)


## Open Issues

There are a number of remaining problems that trigger-pipeline does not solve by itself:


### Discovering the Jenkins Server + API token

To work trigger-pipeline needs to know where the Jenkins server is and how to talk to it. So it needs a URL and an API Token.

There’s no standard way to define that nor any tooling for configuring that. 

So the trigger-pipeline CLI defines a number of [commands to register Jenkins servers](https://github.com/jenkins-x-labs/trigger-pipeline#adding-jenkins-servers) along with the username + API token to use.

Over time we should be able to create some Core capability to automatically populate the Jenkins server registry.


### Setting up the pipelines

Having a `trigger-pipeline` binary is one thing but then creating a custom _jenkins-x.yml_ pipeline file with details of how to find the Jenkins URL + the Secret and setting up webhooks is another issue. 

Currently `trigger-pipeline` is not very developer friendly and will require some wizards that can automate the creation of trigger-pipeline based _jenkins-x.yml._


## FAQs


### Jenkins X used to install a Jenkins Server into Kubernetes for me. How do I install Jenkins now?

Jenkins is to Jenkins X as Java is to Javascript - all they share is a name. You don't need Jenkins installed to use Jenkins X. That said, you may want to install Jenkins in the same Kubernetes cluster as Jenkins X. Here's some links that explain how you can do it:


*   Jenkins Operator - [https://jenkinsci.github.io/kubernetes-operator/docs/installation/](https://jenkinsci.github.io/kubernetes-operator/docs/installation/)
*   Jenkins Helm Chart - [https://github.com/helm/charts/tree/master/stable/jenkins](https://github.com/helm/charts/tree/master/stable/jenkins)

As well as some commercial offerings:

*   CloudBees Core - [https://docs.cloudbees.com/docs/cloudbees-jenkins-distribution/latest/distro-install-guide/kubernetes](https://docs.cloudbees.com/docs/cloudbees-jenkins-distribution/latest/distro-install-guide/kubernetes)
*   Google Kubernetes Engine - [https://cloud.google.com/solutions/jenkins-on-kubernetes-engine-tutorial](https://cloud.google.com/solutions/jenkins-on-kubernetes-engine-tutorial)
