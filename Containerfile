FROM quay.io/fedora/fedora-coreos:stable

RUN dnf -y install \
    bat \
    below \
    btop \
    compsize \
    fd-find \
    fish \
    iftop \
    ncdu \
    smartmontools \
    sysbench \
    sysstat \
    unzip \
    upower \
    wget \
    zip \
    && dnf clean all
