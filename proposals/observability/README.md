---
title: Observability
linktitle: Observability
description: Observability for Jenkins X
weight: 80
---

# Observability for Jenkins X

One of the goals of Jenkins X is to glue the "right" components together, and give you a nice experience, where you don't need to spend a lot of time configuring a low-level component to get DNS or certificates for example.
But for the moment there is one big topic which is missing: observability.

Our goal here is to package observability as part of Jenkins X, for:
- the platform itself
- "devops" indicators

## Platform Observability

This is the first step of this project: setup an observability stack so that we can:
- get the logs of all the Jenkins X components: Tekton, Lighthouse, cert-manager, ...
- get the metrics - as dashboards - for all these components
- setup alerting using logs-based or metrics-based rules

People should be able to quickly:
- get a "big picture" of the cluster health
- find all issues/errors
- get alerted if something goes wrong: a certificate which can't be renewed, a pod which can't start, ...

## "devops" indicators

This is the second step of this project: use the observability stack to collect and visualize Continuous Delivery Indicators.

We can collect all kinds of events happening in the clusters:
- Pull Requests
- Pipelines
- Releases
- Deployments
- ...

and then use this data to calculate indicators such as the 4 key devops metrics: 
- mean lead time
- deployment frequency
- mean time to recover
- change failure rate

and we can even go 1 step further, and use the [SPACE framework](https://queue.acm.org/detail.cfm?id=3454124k) to present system metrics.

Our goal here is to give people insights into their workflows/processes, so that they can continuously improve them.

## Implementation

The selected observability stack is Grafana, because:
- it's open-source
- has support for logs/metrics/traces
- is written in go
- has a low memory footprint
- great kubernetes integration

So we're using:
- [Promtail](https://grafana.com/docs/loki/latest/clients/promtail/) to collect the logs from all running containers
  - promtail is deployed as a daemonset on every node of the cluster, so that it can read the Kubernetes log files
- [Loki](https://grafana.com/docs/loki/latest/) to ingest the logs
- [Prometheus](https://prometheus.io/) to collect and ingest the metrics from the running pods
- [Grafana](https://grafana.com/docs/grafana/latest/) to visualize logs & metrics

The CD Indicators collector will be written as a go application
- watching for kubernetes events on the PipelineActivities
- watching for Kubernetes events on the Releases
- watching for github events through lighthouse - configured as an external plugin in lighthouse
And writting data into a PostgreSQL database, which will be setup as a datasource in Grafana.

Grafana dashboards will be dynamically loaded from ConfigMaps, which will enable:
- an easy packaging of Jenkins X own dashboards: https://github.com/jenkins-x-charts/grafana-dashboard
- Jenkins X users to easily write their own dashboards, and manage them in a gitops-friendly workflow
