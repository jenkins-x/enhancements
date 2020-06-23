---
title: K8s-native best practices
linktitle: K8s-native best practices
description: K8s-native best practices
type: docs
weight: 30
---

## 1. Overview

This document aims to establish best practices for k8s-native components in Jenkins X.
Instead of pointing to the Operator Pattern as a well-established practice it
should clarify what that means in particular and how Jenkins X can benefit from it.

## 1.1 Motivation

In general there is a need to decompose Jenkins X for several reasons,
particularly maintainability, extensibility and security.
Kubernetes is very well suited for integration of different components
from various vendors (besides abstracting cloud providers) due to
its way of decoupling components using its API and has become a defakto standard.
Jenkins X can benefit from that because users/companies usually have other
tools that needs to integrate with their CI/CD infrastructure or simply
have special requirements they want to fit into their CI/CD technology.
Having all business logic implemented directly within a monolithic CLI
does not support the k8s way well.
However when every Jenkins X component communicates with the other indirectly
using the k8s API there can be a k8s-native extension point for everything naturally -
which makes it easier for the community to contribute and particularly
to build apps that can hook into every process and eventually can be integrated in the same way by other apps.

## 1.2 Background

At the moment k8s is mostly used as a document database and k8s API resource changes are not consequently used to trigger business logic.
Also some information is hard to query since the CRDs are not denormalized or there is no particular CRD for it.
This makes it hard to understand and particularly to extend Jenkins X.
With more features it will also become harder to maintain.  

## 2. Kubernetes concepts

Besides abstracting cloud provider APIs Kubernetes is a platform designed for automation and integration.
As such it shares many goals with a CI/CD platform in general Jenkins X can benefit from.  

The core of Kubernetes is the generic, extensible API which takes the concept of modularity to a higher level of abstraction:
API kinds (resource types) serve as interfaces and controllers serve as their implementation.
New API kinds can be added as _Custom Resource Definitions_ (CRD). Their instances are called _Custom Resources_ (CR).
A custom component consists of one or many CRDs and a controller for each.

### 2.1 A Controller in Kubernetes

A Kubernetes Controller manages CRs of a single CRD by watching the CRs itself as well as all secondary resources it creates for each CR or that are referenced by the CR.
For each change a reconcile request is scheduled. The controller is run inside a reconcile loop that processes the reconcile requests.
Within the reconcile loop there should be no long blocking code: If a resource is not (yet) in its desired state during a reconcile iteration the controller should not explicitly wait for its state to change but return so that the next iteration may check the state again and eventually finish the process.
Meanwhile the reconcile loop is free to process other requests.
Correspondingly watches must be implemented carefully to avoid deadlocking processes.
During these reconcile iterations status changes of the depending resources must be written back to the status of the owning/primary resource
in order to enable other components to access its state easy and performant.  

Controllers watch custom resources (CRs, instances of CRDs) and react on them asynchronously without any dependency to another controller but to other API resources only.
This way Kubernetes is also kind of a large Inversion of Control container.
The asynchronous nature of implementing controllers in a non-blocking way also results in resilient components with little resource consumption - when implemented correctly.

In order to avoid blocking the controller's reconcile loop its implementation should avoid querying external APIs and doing computation intensive tasks
but simply query the Kubernetes API and, depending on its state, create/update other Kubernetes API objects.
For instance long running logic can be moved into a Pod that is created by a controller.
It should also not actively wait for the created/updated API objects to reach a certain state. Instead it should be ensured that these objects are watched
so that a new reconcile request is created whenever such an object changes.  

This architecture allows to hide complex imperatively coded processes behind a declarative interface that is technology-agnostic and easier to understand for humans.  

### 2.2 The Operator Pattern

The Operator Pattern components that encorporate expert knowledge for a particular application in order to automate its operation.
Therefore these components are called operators.
An operator basically consists of one or many CRDs and a controller for each.
(Following the K8s conventions each git repository that specifies K8s APIs should maintain its CRDs at `deploy/crds` and the corresponding go types at `pkg/apis`.)

## 3. Principles

This section proposes some principles we should embrace. Most of them are valid beyond Kubernetes.

* Inversion of Control: Build passive components whose processes are triggered by events or changes in watched API resources.
  * Build components in a way so that they can be developed and tested ideally isolated from the rest
  * Support running as much as possible in minikube to lower the contribution and experimentation barrier.
* Modularity:
  * Design CRDs modularly so that they can be reused/combined with other components.
* Resilience: Favour small pieces of business logic that can be run in a controller's reconcile loop over long-running blocking code with active retry implementations.
* Performance/Concurrency: Don't run long blocking code within a controller's reconcile loop (otherwise reduces concurrency).
* Performance: Favour batched API changes (kubectl apply -f -) that don't take time for resources that haven't changed over sequential long running pipelines that do a lot even if it is not necessary (applies to GitOps in particular).
* Simplicity/Usability: Favour declarative k8s-native interfaces over imperative code.
* Usability/Understanding/Performance: Design denormalized CRDs (corresponds to document DB principles): When a controller creates other resources for a given resource it should continuously watch and write back their state to the owning resource so that users have all relevant status information at hand by querying the owning resource only.
  * Correspondingly avoid joining API resources - at least when listing them.
* Security: Don't mix security concerns. Think of how different security-related responsibilities can be separated before implementing new features. Model CRDs so that K8s' RBAC can be leveraged.

## 4. External interface(s) & user load

While Jenkins X cluster-internal process integrations should be done using the Kubernetes API directly
this shouldn't be done unnecessarily with clients outside the cluster because
* Companies may not want to expose their K8s API.
* Exposing k8s API - even if well secured - results in a larger attack surface.
* Clients that rely on k8s API resources must evolve with every (partial) k8s API/CRD change.
* User load should ideally not affect the K8s API server since it is usually not scaled as much as regular cluster workloads and the API server resources must be kept free for cluster-internal operations.

Therefore, if there is no particular need to access the k8s API, an abstract domain-specific middleware API (e.g. JXUI backend) should be used by external clients as a gateway into the cluster (user requests should be served from memory as much as possible using CQRS).
The middleware API also serves as a system boundary between cluster-internal logic/APIs and external/client-side tools (e.g. GUI, CLI) allowing us to evolve both independent from each other.
This way whenever an API version inside the cluster changes (deprecation?!) only the middleware has to be adjusted - not all clients.
Exposing only such a specialized middleware outside the cluster also reduces the attack surface.

## 5. Action plan

1. Discuss, agree on or amend these principles.
1. Apply them while decomposing jx ([proposal #5](../5/README.md)).
1. Apply them when designing new features.

## 6. Potential implementations in Jenkins X

Not everything needs to be implemented as CRD and Kubernetes controller.
However it is beneficial for 3rd party integrations and our own experimentation if a CRD or k8s event is used to trigger each automated business process since this allows to decouple components and 3rd parties to plug in / trigger their own components as a replacement or addition of Jenkins X' components and is an idiom of the k8s platform.

TODO: To be refined:
* SourceRepository controller that accepts pipeline bot invitations (more of a security concern) - maybe not a good idea after all since e.g. github request for bot invitations could hang and therefore block the reconcile loop -> would need to spawn a pod to accept the invite
* Promotion controller that triggers a rollout and reflects its state in the corresponding CR's status so that clients (like jxui) can easily query it) - question remains how to make this work consistently with GitOps
* ...
