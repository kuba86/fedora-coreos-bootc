FROM quay.io/fedora/fedora-coreos:stable

COPY --chown=root:root --chmod=644 files/ /etc/yum.repos.d/

RUN dnf -y install --setopt=install_weak_deps=True \
    incus \
    incus-agent \
    && dnf -y install --setopt=install_weak_deps=False \
    bat \
    below \
    binutils \
    btop \
    compsize \
    duf \
    etckeeper \
    eza \
    fd-find \
    fish \
    git \
    iftop \
    k3s-selinux \
    mkpasswd \
    ncdu \
    p7zip \
    smartmontools \
    sysbench \
    sysstat \
    tailscale \
    unzip \
    usbutils \
    upower \
    wget \
    zip \
    && dnf clean all \
    && rm -rf /var/cache/{dnf,yum} \
    && rm -rf /var/tmp/* /tmp/*
