FROM quay.io/fedora/fedora-coreos:stable

COPY --chown=root:root --chmod=644 files/ /etc/yum.repos.d/
COPY packages.txt packages-weak.txt /tmp/

RUN dnf -y install --setopt=install_weak_deps=True \
    $(cat /tmp/packages-weak.txt) \
    && dnf -y install --setopt=install_weak_deps=False \
    $(cat /tmp/packages.txt) \
    && dnf clean all \
    && rm -rf /var/cache/{dnf,yum} \
    && rm -rf /var/tmp/* /tmp/*
