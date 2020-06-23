****---
title: Decomposition of Jenkins X
linktitle: Decomposition of Jenkins X
description: Decomposition of Jenkins X
type: docs
weight: 50
---

## 1. Overview

This document outlines the work for decomposing Jenkins X into a series of reusable libraries.

## 1.1 Motivation

At the moment, the source code that comprises the main JX binary is tightly coupled and difficult to work on.  Changes have
unintended consequences and this makes the codebase fragile.

One of the design goals in Accelerate is to have a **Loosely Coupled Architecture** - in particular: 

_The goal is for your architecture to support the ability of teams to get their work done—from design through to deployment—without requiring high-bandwidth communication between teams._

## 1.2 Background

The main [JX repository](https://github.com/jenkins-x/jx) contains over 250k lines of code, creating Apps / Extensions / Binary Plugins is difficult without adding a dependency back onto the JX repo.

It should be possible to separate the repository out into a series of reusable libraries so only what is needed can be imported.

## 2. Design

There are currently a number of proposed repositories/modules, some of these are currently in flight.

### Existing Modules

* [jx-api](https://github.com/jenkins-x/jx-api): JX CRDs / Installation Requirements
* [jx-kube-client](https://github.com/jenkins-x/jx-kube-client): A helper module to create a Kubernetes rest config
* [jx-vault-client](https://github.com/jenkins-x/jx-vault-client): longer term, it may make sense to deprecate this.
* [go-scm](https://github.com/jenkins-x/go-scm): All 

### Proposed Modules

* jx-kube: It may make sense to refactor some of the higher level utils/kube functions within JX into its own package to make them reusable.
* Version Streams: Would these make sense to be moved out of JX
* Gitter?
* Updatebot (jx create pr)? This would have value outside of the core JX codebase 
* Storage APIs?
* Cloud APIs?

## 2.1. Action Plan

1. *Agree on a way forward!*
1. Ensure [Kubernetes Dependency Updates PR](https://github.com/jenkins-x/jx/pull/7313) is merged.
1. Re-introduce [jx-api](https://github.com/jenkins-x/jx-api) as a dependency within [jx](https://github.com/jenkins-x/jx)
1. Test and Release

Once we have completed this once, we should be able to repeat the following process a number of times

1. Identify code to be extracted
1. Extract code into new repo
1. Release new repository
1. Reintroduce library as a dependency inside JX
1. Repeat as required.

## 2.2 Considerations for New Repositories

All new repositories should aim for the following:

* Basic documentation to explain how the module should be used
* A full set of [linters](https://golangci-lint.run/usage/linters), suggesting (asciicheck bodyclose deadcode dogsled dupl errcheck goconst gofmt goimports gosec gosimple govet ineffassign interfacer misspell staticcheck structcheck typecheck unconvert unparam unused varcheck), ideally add gocyclo, nestif & gocritic
* Tests
* [Go Report Card](https://goreportcard.com/)
* Should aim to use [Semantic Versioning](https://semver.org/)

Q: It may be possible to template this out? or even use a buildpack to create this?

## 3. Acceptance Criteria

I think we can say that this has been successful when new Apps / Operators / Plugins can be created for Jenkins-X without
having to depend on the JX repository.  We must provide all the wiring to make this easy.  

It should be easier to do the right thing, than the wrong thing.

## 4. FAQ

**When should we start this?** We should aim to start this immediately, new functionality should be written in this decomposed way, if 
we ultimately decide that this is a bad idea, Its far easier to refactor something into the JX codebase than it is to refactor something out.



