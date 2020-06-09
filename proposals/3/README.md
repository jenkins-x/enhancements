---
title: Cloud Resource Creation
linktitle: Cloud Resource Creation
description: Cloud Resource Creation
type: docs
weight: 30
---

## 1. Overview

This document outlines the work for extracting cloud resource creation from jx. 

## 1.1 Motivation

At the moment, cloud resources needed by Jenkins X, e.g. service accounts, buckets, cryptographic keys, are generated on the fly.
This creation happens either as part of a `jx create cluster` `jx install` or via `jx boot`.
This proposal outlines an approach to separate cloud resource creation from the Jenkins X install. 

## 1.2 Background

The following drawbacks of `jx boot` are the motivation for this proposal:

* For users, it is not transparent what cloud resource and permissions are needed  by  Jenkins X
* It is hard to limit permissions. At the moment Boot requires full admin permissions on all Cloud APIs
* Code for generating and dealing cloud resources is distributed across multiple commands and files in the source code
* Hard to integrate new cloud provider due to the lack of abstraction
* Hard to maintain current code
* One confusion, for example, is that the various “_verify_” pipeline steps do not purely verify resources, but also lazily create them 

This enhancement proposes a stricter separation of concerns, addressing the points mentioned above as well as introducing the required abstractions to integrate with further cloud providers.

## 2. Design

### 2.1 UX

For the user, the proposed change means that he is responsible for creating all required cloud resources upfront (before installing Jenkins X).
We provide documentation on what is required as well as Terraform scripts to create and manage the resources necessary. 
`terraform apply` can be seen as a replacement for `jx create cluster`.
After implementing this proposal, the Getting Started workflow for the user will exemplary look like this:

```bash
$ git clone https://github.com/jenkins-x/jx-cloud-provisioners
$ cd jx-cloud-provisioners/eks/terraform 
$ terraform init
# edit variables file to provide required details for the cloud provider
# if not provided Terraform will prompt for the required variables 
$ terraform apply -var-file=terraform.tfvars
# this will also create a templated jx-requirements.yml to be used with 'jx boot'

$ cd ..
$ jx boot -r jx-cloud-provisioners/eks/terraform/jx-requirements.yml

```

As a prerequisite, the user needs to have `terraform` as well as `jx` installed.

After the implementation of this proposal, the user has to create cloud resources required by new Jenkins X features upfront, either manually or via the Terraform scripts. 
`jx boot` or `jx upgrade boot` will fail until the user has ensured that the required resources exist.

In the future, the Jenkins X install process (`jx boot`) will always only verify whether a needed resource exists, never create it
When verification fails, the install process halts and needs to provide enough context to the user to identify which cloud resource is missing.

### 2.2. Technical Design

#### 2.2.1 `jx boot` and `jx-requirements.yaml`

For this proposal, the current `jx boot` code stays unmodified.
This allows to use still `jx create cluster` and `jx boot` as is.
The plan is to remove `jx create cluster` in a second step together with a cleaning up of the `jx boot` code.

`jx-requirements.yaml` also stays unmodified.
In the case the user is using the Terraform scripts, he will get a templated `jx-requirements.yaml` as an output of `terraform apply` which can be passed to `jx install`.

#### 2.2.2 Terraform

As part of the enhancement, we are creating a GitHub repository with initially two Terraform setups, one for GKE and one for EKS.
In each case, it is the responsibility of the Terraform script to create the required cloud resources:

* Service accounts
    * _externaldns-sa_
        * optional, only enabled if user wants to use external DNS
        * IAM roles:
            * GKE - roles/iam.workloadIdentityUser, roles/dns.admin
            * EKS - IAM/role and IAM Policy with Route53 permissions., Kubernetes Service Account.  
    * _kaniko-sa_
        * required
        * IAM roles:
            * GKE - roles/iam.workloadIdentityUser, roles/storage.admin, roles/storage.objectAdmin, roles/storage.objectCreator
            * EKS - Covered by the tekton-bot Service Account.
    * _storage-sa_
        * required
        * IAM roles:
            * GKE - roles/iam.workloadIdentityUser, storage.objects.[create|get|delete|update]
            * EKS - S3Access Policy attached to an IAM/role and a Kubernetes Service Account.
    * _tekton-sa_
        * required
        * IAM roles:
            * GKE - roles/iam.workloadIdentityUser, roles/viewer 
            * EKS - IAM/role and IAM Policy with general permissions, Kubernetes Service Account.
    * _velero-sa_
        * optional, only created if the user wants to use Velero
        * IAM roles:
            * GKE - roles/iam.workloadIdentityUser, roles/storage.admin, roles/storage.objectAdmin, roles/storage.objectCreator
            * EKS - S3Access Policy attached to an IAM/role and a Kubernetes Service Account.
    * _vault-sa_
        * required
        * IAM roles:
            * GKE - roles/iam.workloadIdentityUser, roles/cloudkms.admin, roles/cloudkms.cryptoKeyEncrypterDecrypter, roles/storage.objectAdmin
            * EKS - ?
* Storage buckets
    * logs (required)
    * vault (required)
    * reports (optional, same bucket as logs if not provided)
    * repository (optional, used by bucketrepo if enabled)
    * backup (optional, used by Velero if enabled)
* Kryptographic keys

Permissions needed by Kubernetes service accounts for the various Cloud APIs will be managed by [workload identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity).

Similar to the setup in [terraform-google-jx](https://github.com/jenkins-x/terraform-google-jx), the output of applying the Terraform plan will be a `jx-requirements.yaml` which can then be used as input for `jx boot`.

The Terraform scripts and documentation will discuss and recommend how Terraform state should be managed, e.g. via remote storage in a cloud bucket.

Initially, the versioning of the repository containing the Terraform scripts is not automatically linked to `jx` resp [jenkins-x-boot-config](https://github.com/jenkins-x/jenkins-x-boot-config) releases.
Moving forward we can either automatically update the Terraform `jx-requirements.yaml` templates as new releases of the boot config become available or we integrate the install of Jenkins X into the Terraform script via the Helm provider.

#### 2.2.3 Docs

Ar part of this enhancement the documentation will get extended and will include sections for the following:

* Generic description of the cloud resources needed and their purpose
* Documentation on where to find the Terraform script and how to use them
    * Recommendations on

## 2.3. Out of Scope

* Removal of cloud resource creation code from `jx boot`
* Removal of `jx edit storage` 
    * Removal of `jx create cluster` and `jx install`
* Automate versioning between Terraform scripts and jx releases

## 3. Acceptance Criteria

* A section in the Jenkins X docs outlining the required cloud resources to install Jenkins X
* Terraform script for creation of cloud resources for GKE and EKS
    * Scripts use workload identity and IAM Roles for Service Accounts
* Documentation on how to best manage the Terraform state file
* Ability to boot Jenkins X on GKE and EKS using cluster prepared with Terraform
    * Installation of Jenkins X with a user with limited permissions (unable to create cloud resources) 
* Identification of items for later cleanup (removal of cloud creation code within Boot) and create backlog items

## 4. References

* [https://github.com/jenkins-x/terraform-google-jx](https://github.com/jenkins-x/terraform-google-jx)
* [https://github.com/jenkins-x-labs/jenkins-x-installer](https://github.com/jenkins-x-labs/jenkins-x-installer)
* [https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
* [https://registry.terraform.io/modules/terraform-google-modules/kubernetes-engine/google/7.1.0/submodules/workload-identity](https://registry.terraform.io/modules/terraform-google-modules/kubernetes-engine/google/7.1.0/submodules/workload-identity)
