---
title: Propagation of changelogs
linktitle: Propagation of changelogs
description: Propagation of changelogs
type: docs
weight: 80
---

## 1. Overview

This document outlines how to propagate change logs along with version changes when using `jx promote` and `jx updatebot pr`.

## 1.1 Motivation

At the moment, the change log resulting from upgrading a dependency of an application at best shows to which version of 
what dependency the upgrade was made. A lot more information would be useful to show, and it should be fairly easy to achieve. 

## 1.2 Goal

The goal is that the resulting change log of a dependency upgrade done using `jx promote` or `jx updatebot pr` should show
the change logs of the dependency. If there are versions that has not been deployed also the change log for the versions
skipped over should be included.

Where possible dependency updates should also be added to the changelog.

The behaviour should be easily adaptable both in pipelines and for cluster repositories.  

## 2. Design proposal

`jx changelog create` already supports generating a change log document to a file in Markdown format.
The content of this file can then be added after a divider (I propose the section divider "`-----`") to the body of the pull request by 
`jx promote` and `jx updatebot pr`. When `jx promote` and `jx updatebot pr` is updating an existing pull request any
existing change log of the PR should be kept and the changelog for the current upgrade is added.

When `jx changelog create` encounters the merge of a pull request it should include the changelog from its body in the generated changelog.
This has the added benefit that manually added or changed changelogs from these pull requests also will turn up in the changelog. 

For added context in cluster repos the change in `docs/releases.yaml` could be used to populate the section
**Dependency Updates** that is already partly supported by `jx changelog create`.

To support this by default the invocations of `jx changelog create`, `jx promote` and `jx updatebot pr` in 
`jenkins-x/jx3-pipeline-catalog` needs to be updated.

Also `src/Makefile.mk` in `jenkins-x/jx3-versions` needs to be updated to support changelog for cluster repositories.
Since `jx changelog create` needs tags to create the changelog and tagging currently is only done when 
`KUBEAPPLY = kpt-apply` is set in the repository Makefile this will initially be required to get the changelog
functionality for cluster repositories.

The command line arguments needs to be amendable using variables to ease customization.

## 3. Affected repositories

As outlined above the following repositories need changes:

- [ ] `jenkins-x-plugins/jx-changelog`
- [ ] `jenkins-x-plugins/jx-promote`
- [ ] `jenkins-x-plugins/jx-updatebot`
- [ ] `jenkins-x/jx3-versions`
- [ ] `jenkins-x/jx3-pipeline-catalog`
