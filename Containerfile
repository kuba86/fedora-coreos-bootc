FROM quay.io/fedora/fedora-coreos:stable

COPY --chown=root:root --chmod=644 files/ /etc/yum.repos.d/
COPY packages.txt packages-weak.txt /tmp/

RUN xargs -ra /tmp/packages-weak.txt dnf -y install --setopt=install_weak_deps=True \
    && xargs -ra /tmp/packages.txt dnf -y install --setopt=install_weak_deps=False \
    && dnf clean all \
    && rm -rf /var/cache/{dnf,yum} \
    && rm -rf /var/tmp/* /tmp/*
