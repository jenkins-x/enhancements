---
title: Jenkins X gitops rewrite
linktitle: Jenkins X gitops rewrite
description: Jenkins X gitops rewrite
type: docs
weight: 50
---

## 1. Overview

This document is a proposal to rewrite the entire gitops part of Jenkins X to make it more modern and kubernetes native (like argo/flux)

## 1.1 Motivation

The cluster git repository of Jenkins X is made up of many bash and makefiles.
Instead of using bash and makefile, we should look at implementing gitops in a language like golang

This could be a potential gitops project!

## Proposal

A pull based gitops controller in golang.

## Alternatives

Remove the gitops part of Jenkins X and just use Argo/Flux.
