FROM quay.io/fedora/fedora-coreos:stable

COPY --chown=root:root --chmod=644 files/ /etc/yum.repos.d/

RUN dnf -y install \
    bat \
    below \
    bind-utils \
    binutils \
    btop \
    compsize \
    duf \
    eza \
    fd-find \
    fish \
    git \
    iftop \
    iputils \
    iproute \
    jq \
    k3s-selinux \
    mkpasswd \
    nano \
    ncdu \
    ncurses \
    p7zip \
    procps-ng \
    rsync \
    smartmontools \
    sysbench \
    sysstat \
    tailscale \
    unzip \
    upower \
    util-linux \
    wget \
    which \
    zip \
    && dnf clean all \
    && rm -rf /var/cache/yum
