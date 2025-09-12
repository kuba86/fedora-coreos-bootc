FROM quay.io/fedora/fedora-coreos:stable

COPY --chown=root:root --chmod=644 files/ /etc/yum.repos.d/

RUN dnf -y install \
    bat \
    below \
    binutils \
    btop \
    compsize \
    duf \
    fd-find \
    fish \
    iftop \
    k3s-selinux \
    mkpassed \
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
