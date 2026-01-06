# ---------- Build stage ----------
   FROM alpine:3.22.1 AS builder

   # Do not specify default value as docker buildx will not set the arguments otherwise, see https://github.com/docker/buildx/issues/510
   ARG TARGETOS
   ARG TARGETARCH
   
   ARG KUBECTL_VERSION=v1.34.2
   ARG HELM_VERSION=v3.18.5
   ARG KUSTOMIZE_VERSION=v5.7.1
   
   RUN apk add --no-cache curl tar gzip coreutils grep
   
   WORKDIR /tmp
   
   # ----- Download and verify Helm -----
   RUN curl -fsSLO https://get.helm.sh/helm-${HELM_VERSION}-${TARGETOS}-${TARGETARCH}.tar.gz && \
       curl -fsSLO https://get.helm.sh/helm-${HELM_VERSION}-${TARGETOS}-${TARGETARCH}.tar.gz.sha256 && \
       echo "$(cat helm-${HELM_VERSION}-${TARGETOS}-${TARGETARCH}.tar.gz.sha256)  helm-${HELM_VERSION}-${TARGETOS}-${TARGETARCH}.tar.gz" | sha256sum -c - && \
       tar xf helm-${HELM_VERSION}-${TARGETOS}-${TARGETARCH}.tar.gz && \
       mv ${TARGETOS}-${TARGETARCH}/helm /tmp/helm
   
   # ----- Download and verify kubectl -----
   RUN curl -fsSLo /tmp/kubectl https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${TARGETOS}/${TARGETARCH}/kubectl && \
       curl -fsSLo /tmp/kubectl.sha256 https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${TARGETOS}/${TARGETARCH}/kubectl.sha256 && \
       echo "$(cat /tmp/kubectl.sha256)  /tmp/kubectl" | sha256sum -c - && \
       chmod +x /tmp/kubectl
   
   # ----- Download and verify kustomize -----
   # GitHub release tag: kustomize/vX.Y.Z
   # File name: kustomize_X.Y.Z_linux_amd64.tar.gz
   RUN curl -fsSLO https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_${TARGETOS}_${TARGETARCH}.tar.gz && \
       curl -fsSLO https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/checksums.txt && \
       grep "kustomize_${KUSTOMIZE_VERSION}_${TARGETOS}_${TARGETARCH}.tar.gz" checksums.txt | sha256sum -c - && \
       tar xzf kustomize_${KUSTOMIZE_VERSION}_${TARGETOS}_${TARGETARCH}.tar.gz
   
   
   # ---------- Runtime stage ----------
   FROM alpine:3.22.1
   
   RUN apk add --no-cache \
         bash \
         bash-completion \
         busybox-extras \
         net-tools \
         vim \
         curl \
         jq \
         yq \
         grep \
         wget \
         tcpdump \
         git \
         ca-certificates && \
         update-ca-certificates
   
   # Copy verified binaries
   COPY --from=builder /tmp/helm /usr/local/bin/helm
   COPY --from=builder /tmp/kubectl /usr/local/bin/kubectl
   COPY --from=builder /tmp/kustomize /usr/local/bin/kustomize
   
   # Enable kubectl bash completion globally
   RUN echo -e 'source /usr/share/bash-completion/bash_completion\nsource <(kubectl completion bash)' >> /etc/bash.bashrc
   
   # Install Helm plugin
   RUN helm plugin install https://github.com/helm/helm-mapkubeapis
   
   COPY entrypoint.sh /usr/local/bin/entrypoint.sh
   
   ENTRYPOINT ["entrypoint.sh"]