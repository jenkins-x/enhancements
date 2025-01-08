---
title: Use go templating for quickstarts and packs
linktitle: Use go templating for quickstart
description: Proposal for improving templating of apps from quickstarts and packs
type: docs
weight: 80
---

# Problem: The templating ability in quickstarts are very limited

Currently only a very limited number of fixed strings are replaced in files in a quickstart and the
selected pack:

- `REPLACE_ME_APP_NAME`
- `REPLACE_ME_GIT_PROVIDER`
- `REPLACE_ME_ORG`
- `REPLACE_ME_DOCKER_REGISTRY_ORG`

The format of the inserted strings are also fixed to lower case.

# Proposal

Introduce configuration of the templating. If the file .jx/gotemplate.yaml exists in a quickstart
repository it is read and used to configure the templating. Just the presense of this file (with the correct
apiVersion and kind) would enable go template support. To reduce the risk for interference with go
templating of k8s resources and for other purposes the delimiters would by default be '[[' and ']]'
instead of the default '{{' and '}}'. But the use of other delimiters should be possible to configure.

I propose that also a pack could have a .jx/gotemplate.yaml, which would control the templating of
the pack.

With this enabled for example `REPLACE_ME_APP_NAME` could be replaced with `[[ .AppName ]]`. A
typical case where a greater flexibility is needed is to accomodate conventions for casing in
different languages. While that could be accomodated with basic go template string functions I
propose that the functions of https://docs.gomplate.ca/ are included by default to alleviate this
task.

Configuration options for gotemplate can be added to .spec of gotemplate.yaml.

There are more information known to jx project that could be in quickstarts. If for example the java
version where exposed the need for multiple packs for different java version could probably be
eliminated.

I also propose support for adding custom values. This could be done in a similar way as it was done
in the apps functionality of Jenkins X 2, where the json schema for a helm chart
(values.schema.json) where used to prompt the user for missing values.

# Drawbacks

Even though the point of this is to make quickstarts and packs more flexible care must be taken not
to overuse templating so maintaining the quickstarts and packs become difficult.

# Fixes

jenkins-x/jx#1839

jenkins-x/jx#1849
