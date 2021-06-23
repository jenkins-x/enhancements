---
title: Gitops Workflow
linktitle: Gitops Workflow
description: New Gitops Workflow Proposal
weight: 80
---

# New Gitops Workflow Proposal

The goal of this proposal is to change the current Jenkins X "Gitops Workflow", and to explain why/how the proposed workflow can improve people's experience with Jenkins X.

## The current Gitops Workflow

The current "gitops workflow" is:

- when an "application" Pull Request is merged, the application release pipeline will:
  - create, package and upload artifacts (container image, helm chart)
  - promote the new release by creating 1 or more PRs on the "gitops" repositories
    - these PRs will "just" change the version of the application (helm chart) in a YAML file
- when a "gitops" Pull Request is merged, the "gitops operator" will:
  - re-generate the kubernetes manifests from the [Helmfile](https://github.com/roboll/helmfile) state - using `helmfile template`
  - commit these manifests in the git repo - in the `config-root` dir
  - and then apply these manifests to the kubernetes cluster - using `kubectl apply`

### The issues with the current Gitops workflow

There are a few issues with this workflow:
- you don't see the impact of changing the version of an application - or adding a new application - until it's merged in master
- if the generation of the manifests fail for some reason, you'll end up with a "broken main branch", and you'll need to look at the git operator logs to find the root cause

### The benefits of the current Gitops workflow

We should note a few benefits from the current workflow:
- storing the "generated" manifests in git is a good practice, because it makes it easy to audit the changes in a manifest. Looking at the "git blame" for a manifest, you can see when a change has been made - although it requires a bit of work to see who/why the change was made, because you'll need to find the previous commit which is associated with a Pull Request to find this information.

## The proposed "improved" Gitops workflow

**What if instead of generating the manifests from the gitops operator, we generate them from the Pull Request pipeline?**

The idea is to switch to the following workflow:

- when an "application" Pull Request is merged, the application release pipeline will:
  - create, package and upload artifacts (container image, helm chart)
  - promote the new release by creating 1 or more PRs on the "gitops" repositories
    - these PRs will "just" change the version of the application (helm chart) in a YAML file
- when a "gitops" Pull Request is created, the Pull Request pipeline will:
  - re-generate the kubernetes manifests from the [Helmfile](https://github.com/roboll/helmfile) state - using `helmfile template`
  - check if there is a diff between the manifests already stored in the git repo - in the `config-root` dir for example
    - if there is a diff, we'll add/commit/push the changes, and stop the pipeline with a failure
- the new git commit/push event will trigger a new run of the PR pipeline:
  - it will also re-generate the manifests, but this time there won't be any diff
  - the pipeline can proceed by validating the manifests, using kubeval, kube-score, ...
  - if everything is good, the pipeline can finish with a success state, so that Lighthouse can auto-merge the PR (or it can be manually approved)
- and when a "gitops" Pull Request is merged, the "gitops operator" will:
  - just apply these manifests to the kubernetes cluster - using `kubectl apply`

### Benefits of this new "improved" workflow

- if you change something in the Helmfile state in a PR, you'll be able to see the real diff and impact in the same PR: you'll see the changes in the kube manifests
- because we generate the manifests at PR-time, it's easy to run a lot of validation on these manifests, giving us more confidence that these manifests can be applied to the cluster without failure
- you'll get an improved audit experience: if you run a "git blame" on a manifest, you'll see right away who did the change, when and why (commit message, PR with link to the upstream application release/PR, ...)
- if the manifests generation fail, you'll see it in the PR, and you'll be able to fix it without impacting the master/main branch
- It's easy for people to customize their gitops repo and the way the manifests are generated, because they can control the generation from the PR pipeline definition. So they can customize the `helmfile template` command, add new steps, ...
- the jx gitops operator will be simplified, because it just needs to run `kubectl apply`
- the jx gitops operator can be replaced by something else, such as flux/argo/fleet or anything that knows how to watch a git repo and apply the manifests stored in it

In conclusion, this workflow is really doing gitops as PR-based operations, because everything is in the PR.

### Challenges

- the generation used to be done by in the target kube cluster directly (by the gitops operator), but now it will be executed in the jx kube cluster - inside a Tekton pipeline - which may or may not be different, if you're using multicluster or not. This may have an impact.
- secrets. It's always the main challenge in gitops ;-)
