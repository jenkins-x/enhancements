---
title: Use Tekton Pipeline Remote Resolution
linktitle: Use Tekton Pipeline Remote Resolution
description: Create our own Tekton Resolver in order to allow Remote Resolution & uses:sourceURI
weight: 100
---

## 1. Overview

This document outlines how we can use Tekton Pipeline Remote Resolution removing some scope from Lighthouse

## 1.1 Motivation

Let's take a single PipelineRun I can use as example, I am running multiple tasks inside it, it can be:
- in parallel
- with runAfter
- finally

Now imagine I have multiple team repositories to maintain with all this logic inside (parallel, runAfter, finally tasks),
Jx3 feature notation `image: uses:sourceURI` (that lets you inherit steps from a git repository without having to copy/paste the source code aross repositories) is amazing, but not enough here because it's only inside a task that the magic appears.

The solution I believe is the following one: [Tekton Pipeline Remote Resolution](https://tekton.dev/vault/pipelines-main/resolution)
- Remote Resolution is a Tekton feature that allows users to fetch tasks and pipelines from remote sources outside the cluster. Tekton provides a few built-in resolvers that can fetch from git repositories, OCI registries etc as well as a framework for writing custom resolvers.
- We can create our own Jx3 Resolver: [How to write a Resolver](https://tekton.dev/vault/pipelines-main/how-to-write-a-resolver)
  - We would be able to put all the parallel, runAfter, finally tasks logic inside a remote Pipeline and just reference it inside our PipelineRuns (a lot easier maintenance !)
  - The resolution would happen after the PipelineRun is applied to Kubernetes and not before
  - We could implement this `image: uses:sourceURI` inside our jx3 tekton resolver
    - [this is the current tekton git resolver](https://github.com/tektoncd/pipeline/blob/main/pkg/resolution/resolver/git/resolver.go)

- This way, we would be closer to Tekton new great solutions, and we would remove from the [WebHook/ChatOps Lighthouse](https://github.com/jenkins-x/lighthouse) the loads of pipelineRuns with `image: uses:sourceURI` logic that needs to happen before the PipelineRun is applied to Kubernetes

This way, we can use Remote PipelineRef / TaskRef from git to have easier maintenance without copy paste, and still be able to use inside them `image: uses:sourceURI`

## 1.2 Goal

The goal is to create our own Jx3-Git Resolver to be able to use Remote Pipeline / Task from Git inside our PipelineRuns with the `image: uses:sourceURI` inheritance working. All this logic could then be removed from the [WebHook/ChatOps Lighthouse](https://github.com/jenkins-x/lighthouse) that could be more focused on Webhook / ChatOps things

## 1.3 Requirements  (I think)
- Kubernetes version: 1.23.x
  - [Tekton Pipeline version: 0.41.0](https://github.com/tektoncd/pipeline/releases/tag/v0.41.0)
- Kubernetes version: 1.22.x
  - Action required: If using Kubernetes 1.22, set PodSecurity flag to true to enforce a restricted pod security level in Tekton namespaces. See https://kubernetes.io/docs/reference/command-line-tools-reference/feature-gates/#feature-gates-for-graduated-or-deprecated-features for more information.


## 2. Design proposal

- Design our Jx3-Git Resolver following [Tekton Remote Pipeline Resolution Resolver Interface](https://github.com/tektoncd/pipeline/blob/main/pkg/resolution/resolver/framework/interface.go)
  - This would need to be able to Resolve remote Git Pipeline & Task
  - This would be nice to still having `image: uses:sourceURI` that allows steps inheritance, injection & cherry-picking
- We would need to then remove this logic from Lighthouse
  - Lighthouse would just present a PipelineRun that is applied in Kubernetes cluster
  - All the PipelineRuns loads logic would be now inside the Jx3-Git Resolver

## 3. Affected repositories

As outlined above the following repositories need changes:

- [ ] `cdfoundation/tekton-helm-chart`
- [ ] `jenkins-x/jx3-versions`
- [ ] `jenkins-x/lighthouse`

## 4. Concerns

## 4.1 Concerns about Jx3 Parameters injection

I am talking about these Jx3 default Parameters:
```
      params:
      - name: BUILD_ID
        value: $(params.BUILD_ID)
      - name: JOB_NAME
        value: $(params.JOB_NAME)
      - name: JOB_SPEC
        value: $(params.JOB_SPEC)
      - name: JOB_TYPE
        value: $(params.JOB_TYPE)
      - name: PULL_BASE_REF
        value: $(params.PULL_BASE_REF)
      - name: PULL_BASE_SHA
        value: $(params.PULL_BASE_SHA)
      - name: PULL_NUMBER
        value: $(params.PULL_NUMBER)
      - name: PULL_PULL_REF
        value: $(params.PULL_PULL_REF)
      - name: PULL_PULL_SHA
        value: $(params.PULL_PULL_SHA)
      - name: PULL_REFS
        value: $(params.PULL_REFS)
      - name: REPO_NAME
        value: $(params.REPO_NAME)
      - name: REPO_OWNER
        value: $(params.REPO_OWNER)
      - name: REPO_URL
        value: $(params.REPO_URL)
      taskSpec:
        params:
        - description: the unique build number
          name: BUILD_ID
          type: string
        - description: the name of the job which is the trigger context name
          name: JOB_NAME
          type: string
        - description: the specification of the job
          name: JOB_SPEC
          type: string
        - description: '''the kind of job: postsubmit or presubmit'''
          name: JOB_TYPE
          type: string
        - description: the base git reference of the pull request
          name: PULL_BASE_REF
          type: string
        - description: the git sha of the base of the pull request
          name: PULL_BASE_SHA
          type: string
        - default: ""
          description: git pull request number
          name: PULL_NUMBER
          type: string
        - default: ""
          description: git pull request ref in the form 'refs/pull/$PULL_NUMBER/head'
          name: PULL_PULL_REF
          type: string
        - default: ""
          description: git revision to checkout (branch, tag, sha, ref…)
          name: PULL_PULL_SHA
          type: string
        - description: git pull reference strings of base and latest in the form 'master:$PULL_BASE_SHA,$PULL_NUMBER:$PULL_PULL_SHA:refs/pull/$PULL_NUMBER/head'
          name: PULL_REFS
          type: string
        - description: git repository name
          name: REPO_NAME
          type: string
        - description: git repository owner (user or organisation)
          name: REPO_OWNER
          type: string
        - description: git url to clone
          name: REPO_URL
          type: string
```

Using Tekton Pipeline Remote Resolution instead of Lighthouse put the PipelineRuns Loads logic after Kubernetes applied the PipelineRun and not before. This means that when using remote Task / Pipeline, we don't want to hardcode inside them the default Jx3 Parameters because this would be too verbose.

I believe then these Jx3 Parameters would need to be injected by this Jx3-Git Resolver, inside:
- PipelineSpec
- TaskSpec
- Finally TasksSpec

We could make this Injecton step optionnal only if a Lighthouse annotation is present, so even Tekton users
could use the `image: uses:sourceURI` feature without directly using the Jx3 ecosystem.
