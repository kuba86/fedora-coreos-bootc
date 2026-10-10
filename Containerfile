FROM quay.io/fedora/fedora-coreos:stable

COPY --chown=root:root --chmod=644 files/ /etc/yum.repos.d/
COPY packages.txt /tmp/

# Install Incus explicitly from COPR; dependencies may use other repositories.
RUN dnf -y install --refresh --setopt=install_weak_deps=True \
        --from-repo=copr:copr.fedorainfracloud.org:jurav59:incus \
        incus incus-agent incus-ui \
    && xargs -ra /tmp/packages.txt dnf -y install --setopt=install_weak_deps=False \
    && dnf clean all \
    && rm -rf /var/cache/{dnf,yum} \
    && rm -rf /var/tmp/* /tmp/*
