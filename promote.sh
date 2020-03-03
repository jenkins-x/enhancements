#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

export CREATED_TIME=$(date '+%a-%b-%d-%Y-%H-%M-%S')
export LOCAL_BRANCH_NAME="changes-${CREATED_TIME,,}"

echo "creating branch $LOCAL_BRANCH_NAME"

# lets setup git
jx step git credentials

git config --global --add user.name JenkinsXBot
git config --global --add user.email jenkins-x@googlegroups.com



git clone https://github.com/jenkins-x/jx-docs.git

MESSAGE="chore: updated enhancements content"

pushd jx-docs
  git submodule update --init --recursive
  git submodule status --recursive
  git pull --recurse-submodules
popd

pushd jx-docs/content/en/docs/labs/enhancements
  git checkout master
  git pull
  cd ..
  git add enhancements
  git commit --allow-empty -m "$MESSAGE"
  git push origin master
popd
