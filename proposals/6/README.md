---
title: Versioning strategy for Jenkins X
linktitle: Versioning strategy for Jenkins X
description: Versioning strategy for Jenkins X
type: docs
weight: 60
---

## New release cycle for Jenkins X

### Past discussions

- [Discussion 1](https://github.com/jenkins-x/enhancements/pull/31)
- [Discussion 2](https://github.com/jenkins-x/enhancements/issues/24)

We should have a rapid release channel which is just versioned latest (which is what we have today, but with versions) and a LTS release (with versions) cadence!

### Requirements

- Clear migration path between supported versions
- Good release notes to help end users decide when a release is important!
- Clear documentation around which kubernetes version is supported by LTS
- Clearly state end of life for each LTS version
- Easy for people to switch to using latest version of the software (rapid release)

### Open questions

We can see how other open source projects are doing this and decide what we want to do

- How many versions should we support?
- What is the release cadence?
  - Weekly
  - Monthly
  - Quarterly
  - Every 6 months
  - Yearly
- What kind of branching strategy do we need? [Trunk](https://trunkbaseddevelopment.com/) based is my preference here. This will avoid merge hells associated with other strategies.
- How do people switch between LTS and rapid release channels?
- When do we do a patch release for a LTS version (should be some factor less than the minor release cycle)? Security fixes need to happen
- Do we version anything in the rapid release channel (anything in the master/main branch basically)
- When do we create the release candidate?
- How to tie Jenkins X release with a Kubernetes release?
- How to account for [plugin version](https://github.com/jenkins-x/jx/blob/main/pkg/plugins/versions.go) in the main jx repo, if no versions are going to be created? Can we just use commit sha? Or should we just have 2 separate types of tags - one for rapid release which is just `X.Y.Z-rapid` and one for LTS release which is `X.Y.Z`?

### Proposal

#### Rapid release channel

- This is what we have today with one change, they have rapid in their tag.
  So instead of `X.Y.Z`, they are tagged as `X.Y.Z-rapid`
- This helps keep the current workflow intact, but adds confusion as we can have similar tags which have very different changes like `1.4.5` vs `1.4.5-rapid`

#### LTS release channel

- The main LTS version is semver compliant, something like `X.Y.Z`. The reason for not using semver is that it adds an additional complexity around when to increment the patch and minor version. Instead any change made to the LTS results in Y being incremented.
- Individual components (like jx, jx-project, jx-pipeline) still follow semantic versioning.
- No auto tag generation - tags are created off the release branch manually by running jx-release version locally by the release engineer
- 4 releases per year, which means one LTS release every 3 months (12 weeks)
- Support each LTS for 3 months, we only support one LTS at any given time
- Security and bug fixes happen when we find issues and need to fix, no specific cadence for them
- Release candidate for LTS to be started 6 weeks before a new release is scheduled
- Testing guidelines (TBD)
  - Test upgrades from last LTS to current - users should not skip LTS versions when upgrading - it might break things for them
- All of the branching to happen in jx3-version repository (probably no need to create a separate LTS version stream repository)
  - Master represents the rapid release channel
  - release branches created from the master branch will be used for LTS release
- All fixes to be done in the trunk (master branch) and then cherry picked into the release branch

### Sample timeline

Start Date of this can be October 15, if the first LTS is supposed to come out in December (6 weeks before december 1) - this starts the code freeze period

October 15: RC.1 released
October 22: RC.2 released

### Questions to consider

What if there is a bug in jx-pipeline and we only want an upgraded version of that in the LTS stream (we dont want any other plugin upgrades)?

Can we not use the current lts version stream?

I think the issue with the current LTS strategy is that it's not possible to cherry pick certain changes. For example, we have a bug in jx-pipeline, there is no guarantee that no change will happen in the trunk (master/main) branch before the jx-pipeline bug fix is included in the version stream.
So we may include unintended changes which might break more things.
Also there is no clear way of getting release candidates out for testing.

### Final proposal

#### Manifesto

- A new Jenkins X LTS release will be available every 3 months.
- We will remove tagging every commit to master on jx3-version repository
- Tags will be manually created for commits in release branch.
- The first release will be 1.0.0, the release branch for this will created in the version stream and named lts-1.0
- Next minor release will be 1.1.0, a new release branch will be created which will be named lts-1.1
- Every tagged release will have detailed migration guide (only from the previous release)
- There will be no breaking changes for any tags in lts-1.0
  - Breaking changes include breaking kubernetes compatibility (If the first tag in lts-1.0 supports kubernetes 1.21, then the last tag needs to support it as well!)

#### Upgrade process

Given a kptfile of this form:

```bash
apiVersion: kpt.dev/v1alpha1
kind: Kptfile
metadata:
  name: versionStream
upstream:
  type: git
  git:
    commit: 17dae4be8673a8e2013c5cd8ee432e12f333f872
    repo: https://github.com/jenkins-x/jx3-versions
    directory: /
    ref: master

```

`jx gitops versionstream --lts` will change it to

```bash
apiVersion: kpt.dev/v1alpha1
kind: Kptfile
metadata:
  name: versionStream
upstream:
  type: git
  git:
    commit: XXXXXXXXX
    repo: https://github.com/jenkins-x/jx3-versions
    directory: /
    ref: lts-1.0
```
