FROM quay.io/fedora/fedora-coreos:stable

COPY --chown=root:root --chmod=644 files/tailscale.repo /etc/yum.repos.d/tailscale.repo
COPY --chown=root:root --chmod=644 files/k3s.repo /etc/yum.repos.d/k3s.repo

RUN dnf -y install \
    bat \
    below \
    btop \
    compsize \
    fd-find \
    fish \
    iftop \
    k3s-selinux \
    ncdu \
    smartmontools \
    sysbench \
    sysstat \
    tailscale \
    unzip \
    upower \
    wget \
    zip \
    && dnf clean all
