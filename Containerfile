FROM quay.io/fedora/fedora-coreos:stable

RUN dnf -y install \
    bat \
    below \
    btop \
    compsize \
    fd-find \
    fish \
    iftop \
    incus \
    incus-agent \
    ncdu \
    nodejs \
    smartmontools \
    sysbench \
    sysstat \
    unzip \
    upower \
    wget \
    zip \
    --exclude=nodejs-docs,nodejs-full-i18n \
    && dnf clean all
