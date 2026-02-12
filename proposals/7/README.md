---
title: Multi-tenant Jenkins X
linktitle: Multi-tenant Jenkins X
description: Multi-tenant Jenkins X
type: docs
weight: 50
---

## Overview

This document is a proposal to add multi-tenancy support to Jenkins X.

## Acknowledgement and credits

This was an initial idea from Damian Keska, who tried to make Jenkins X work in a multi-tenant way.

## Motivation

Jenkins X lacks multi-tenancy support at the moment.
This makes it hard to scale for bigger companies.
Supporting multi-tenancy opens up Jenkins X to be offered as a managed CI/CD service by any vendor in the future.
Argo and flux support it, so it makes sense for us to support it as well.

## Pre-requisite

Some portion of the codebase is hardcoded to use jx as the default install.
Also other namespaces are hardcoded, so that needs to be fixed before we can achieve true multitenancy

## Current state

Jenkins X supports silo'ed multi-tenany at this point, which means every team needs to have their own kubernetes cluster and install Jenkins X there.
This does not scale, and becomes expensive very soon!

What I would ideally want is a way to do multi-tenant install inside a single cluster

## Proposal

An installation of Jenkins X needs the following namespaces at a minimum

- jx
- jx-git-operator
- tekton-pipelines
- secret-infra

secret-infra can be shared across all jx specific namespaces for managing secrets.

There can be 2 ways to achieve multi-tenancy in a single cluster running Jenkins X

### Separate namespaces for each team (separate lighthouse installation for each team)

In this method, each developer team picks their own namespaces for installating Jenkins X.
All jx installations will have their own lighthouse installation.
So team A installs jx in jx-A namespace and team B installs jx in jx-B namespace and so on.

### Separate namespaces for each team (one lighthouse installation for all teams)

In this method, each developer team picks their own namespaces for installating Jenkins X.
There is a separate lighthouse installation in a separate namespace.
Also the UI will be in a separate namespace.
So team A installs jx in jx-A namespace and team B installs jx in jx-B namespace and so on.

### Vcluster

This could be an alternative, but needs more research.

## Timeline and planned work

This would be a good project for GSoC 2023
