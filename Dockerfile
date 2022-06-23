FROM registry.access.redhat.com/ubi8/ubi

RUN yum install -y \
    jq \
    git

RUN rpm --import https://packages.microsoft.com/keys/microsoft.asc

RUN sh -c 'echo -e "[azure-cli]\n\
name=Azure CLI\n\
baseurl=https://packages.microsoft.com/yumrepos/azure-cli\n\
enabled=1\n\
gpgcheck=1\n\
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/azure-cli.repo'

RUN yum install -y azure-cli

ARG TARGETARCH=amd64
ARG AGENT_VERSION=2.195.0

RUN useradd -u 1001 -m agentuser

WORKDIR /azp
RUN if [ "$TARGETARCH" = "amd64" ]; then \
      AZP_AGENTPACKAGE_URL=https://vstsagentpackage.azureedge.net/agent/${AGENT_VERSION}/vsts-agent-linux-x64-${AGENT_VERSION}.tar.gz; \
    else \
      AZP_AGENTPACKAGE_URL=https://vstsagentpackage.azureedge.net/agent/${AGENT_VERSION}/vsts-agent-linux-${TARGETARCH}-${AGENT_VERSION}.tar.gz; \
    fi; \
    curl -LsS "$AZP_AGENTPACKAGE_URL" | tar -xz

RUN ./bin/installdependencies.sh

COPY ./start.sh .
RUN chmod +x start.sh

RUN chown -R 1001:0 $HOME && \
    chown -R 1001:0 /azp && \
    chmod -R g+rw $HOME && \
    chmod -R g+rw /azp

# Buildah envs
ENV BUILDAH_ISOLATION=chroot \
    STORAGE_DRIVER=vfs

# Install buildah
RUN yum -y reinstall shadow-utils && \
    yum install buildah -y --exclude container-selinux && \
    yum clean all && \
    rm -rf /var/cache/yum/ && \
    rm -rf /var/cache/dnf/

# Buildah configurations
RUN echo agentuser:10000:65536 > /etc/subuid && \
    echo agentuser:10000:65536 > /etc/subgid

# Install Java and Maven
RUN yum install -y \
    java-11-openjdk-devel \
    maven

WORKDIR /usr/bin

# Install oc
RUN curl -LsS https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-client-linux.tar.gz | tar -xz && \
    chmod +x /usr/bin/oc

# Install Helm
RUN curl -LsS https://mirror.openshift.com/pub/openshift-v4/clients/helm/latest/helm-linux-amd64.tar.gz | tar -xz --no-same-owner

WORKDIR /azp

ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk

# Capabilities
ENV JavaVersion=Java11
ENV Maven=installed
ENV Buildah=installed
ENV Oc=installed
ENV Helm=installed

USER 1001

ENTRYPOINT [ "./start.sh" ]
