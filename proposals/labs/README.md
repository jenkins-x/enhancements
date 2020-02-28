
# 2: Labs


<table>
  <tr>
   <td><strong>Champions</strong>
   </td>
   <td>James Rawlings
   </td>
  </tr>
  <tr>
   <td><strong>Story / Task</strong>
   </td>
   <td>New features for Jenkins X 
   </td>
  </tr>
</table>

# 1. Overview

We want to continue to innovate with Jenkins X, increase community contributions while all the time ensuring Jenkins X continues to build stability and reliability.

This proposal introduces the idea of creating an incubation area of sorts called Jenkins X Labs, here we can experiment, inovate and attract wider community contribution, working in a sandboxed area so that newer changes do not go into the main codebase until there's confidence in them.

Looking at how other heavily based CLI projects work it seems that some like `gcloud` have the concept of `alpha` and `beta` CLI components that introduce changes to users who opt into them.  This is a great way to gather feedback and reduce the risk of changes that need to differ significantly or be deprecated.

## 1.1 Motivation

There's a lot of innovation happening in the Kubernetes ecosystem that Jenkins X would like to integrate with, there's also a lot of innovation to happen in the Jenkins X community too, until now it has been hard to embrace this whilst also maintaining a hight level of stability in the main codebase.  Given that we use trunk based develpoment as recommended by Accelerate it's easy for changes that may alter or become deprecated to be introduced.

We would like to increase the features that people can use, collaborate on and provide feedback so that we continually improve at a good rate.

# 2. Design

Introduce a new GitHub Organisation called [Jenkins X Labs](https://github.com/jenkins-x-labs) which is an upstream incubation hub for Jenkins X that encourages innovation and collaboration on areas that we would like to trial and gather feedback before features appearing in the well supported mainstream codebase.

Most changes for Jenkins X go through the [jx](https://github.com/jenkins-x/jx) CLI repository which has grown into a monolith and has a number of downstream dependencies.  We have been working with a Proof of Concept in Labs that takes a microservices approach to creating commands that inturn can be used to create `alpha` or `beta` binaries that can be optionally installed via `jx`.

So to be clear the proposal for labs is generic and not only focused on the `jx` CLI.  We will want to take similar steps to building docker images, quickstarts, buildpacks etc that use labs features so they don't appear in Jenkins X until feature complete.

An interesting obeservation has been made that using this microservices approach combined with the `alpha` and `beta` commands, it could make for a good way to refactor out the current `jx` monolith, statically importing dependencies from `jx` when we need them but over time refactoring into a more modular approach that will help with maintainability, supportability and testability.

Taking a microservices approach for the CLI will surely bring new challanges but given that we push microservice with the Jenkins X project it is another area of dogfooding that we can learn from and pass on a great experience to users.

## 2.1 Process

This proposal is about creating an environment, culture and process that aids innovation and maintains reliability.  We have a high level suggestion for a process to take features from experimental through to alpha, beta and GA using semantic vesioning for any API changes.

The Labs GitHub Org maintains the list of alpha commands, once defined acceptace for that feature is acheived the feature will move to beta which is owned by the Jenkins X GitHub Org.  There is an expectation that feature, UX and APIs around it will largely stay the same as it matures from beta to GA because the feature will have been proven with community feedback and other acceptance criteria.  Any chnages to this during `beta` should be communicated and agreed on by the Labs organisation to ensure users that take part in the alpha commands continue to provide feedback.

When a feature that may and probably will span multiple repos, beit CLI, images, quickstarts, charts etc we will make sure that there is good involvement and understanding of features so they can be picked up and moved to `beta` inside the Jenkins X org.  This will be a learning process where we will look to always improve.

## 2.1 Technical

* we are suggesting is that `jx` has the ability to include the `alpha` and `beta` commands
* images built within the labs organisation will be pushed to gcr.io/jenkinsx-labs so that users will be able to identify them on inspection.



## 2.3. Out of Scope

* what commands are alpha or what features we start with, the process is about how not what.

# 3. Acceptance Criteria for this Proposal

* approval from the [Jenkins X steering committee](https://github.com/jenkins-x/steering)

