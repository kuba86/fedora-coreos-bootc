# fedora-coreos-bootc

## Ansible:
```yaml
- name: Fedora CoreOS bootc rebase
  hosts: coreos
  gather_facts: false
  tasks:
    
    - name: Rebase to bootc image and reboot (raw)
      become: true
      raw: |
        set -euo pipefail
        IFS=$'\n\t'
        
        kuba86_image="ostree-unverified-registry:ghcr.io/kuba86/fedora-coreos-bootc:stable"
        fedora_image="$(rpm-ostree status --booted --json | jq -r '.deployments[] | select(.booted) | .["container-image-reference"]')"
        
        if [[ "$fedora_image" == "$kuba86_image" ]]; then
          echo "kuba86 image already set"
        else
          echo "rebasing to kuba86 image"
          systemctl disable --now zincati.service && \
          systemctl mask zincati.service && \
          rpm-ostree rebase "$kuba86_image" && \
          systemctl enable --now bootc-fetch-apply-updates.timer && \
          systemd-run --unit=delayed-reboot --on-active=15s systemctl reboot
        fi
      register: fedora_coreos_bootc_rebase
      changed_when: "'rebasing to kuba86 image' in fedora_coreos_bootc_rebase.stdout"
    
    - name: Wait for host to become reachable after rebase
      ansible.builtin.wait_for_connection:
        delay: 20
        sleep: 5
        timeout: 600
      when: fedora_coreos_bootc_rebase.changed

```

## Build locally:
```bash
podman pull quay.io/fedora/fedora-coreos:stable && \
podman build --file=Containerfile --tag=fedora-coreos-bootc:stable && \
podman login ghcr.io && \
podman push --format oci localhost/fedora-coreos-bootc:stable ghcr.io/kuba86/fedora-coreos-bootc:stable && \
podman rmi quay.io/fedora/fedora-coreos:stable localhost/fedora-coreos-bootc:stable
```
