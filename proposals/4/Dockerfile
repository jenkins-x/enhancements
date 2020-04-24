# part of the Dockerfile used to build the container image used to run "jx preview" with helmfile

# install helm
ENV HELM_VERSION 2.14.2
ENV HELM_HOME "/helm"
RUN echo "Installing Helm ${HELM_VERSION}" \
 && curl -f https://storage.googleapis.com/kubernetes-helm/helm-v${HELM_VERSION}-linux-amd64.tar.gz | tar xzv \
 && mv linux-amd64/helm /usr/bin/ \
 && mv linux-amd64/tiller /usr/bin/ \
 && rm -rf linux-amd64 \
 && helm init --client-only

ENV HELM3_VERSION="3.2.0"
RUN echo "Installing Helm3 ${HELM3_VERSION}" \
 && curl -f https://get.helm.sh/helm-v${HELM3_VERSION}-linux-amd64.tar.gz | tar xzv \
 && mv linux-amd64/helm /usr/bin/helm3 \
 && rm -rf linux-amd64

ENV HELM_PLUGINS="/helm/plugins"
RUN echo "Installing Helm3 plugins in ${HELM_PLUGINS}" \
 && export XDG_DATA_HOME="/" \
 && helm3 plugin install https://github.com/futuresimple/helm-secrets --version v2.0.2 \
 && helm3 plugin install https://github.com/databus23/helm-diff --version v3.1.1 \
 && helm3 plugin install https://github.com/hayorov/helm-gcs --version 0.3.1 \
 && unset XDG_DATA_HOME

ENV HELMFILE_VERSION 0.111.0
RUN echo "Installing helmfile ${HELMFILE_VERSION}" \
 && curl -LO https://github.com/roboll/helmfile/releases/download/v${HELMFILE_VERSION}/helmfile_linux_amd64 \
 && chmod +x helmfile_linux_amd64 \
 && mv helmfile_linux_amd64 /usr/bin/helmfile

# install kubectl
ENV KUBECTL_VERSION="1.15"
RUN echo "Installing kubectl ${KUBECTL_VERSION}" \
 && curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable-${KUBECTL_VERSION}.txt)/bin/linux/amd64/kubectl \
 && chmod +x kubectl \
 && mv kubectl /usr/bin/