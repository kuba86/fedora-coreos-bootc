# fedora-coreos-bootc

on installed Fedora CoreOS run:
```bash
systemctl stop zincati.service && \
rpm-ostree rebase "$kuba86_image" && \
systemctl reboot
```

or via Ansible:
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
        
        kuba86_image="ostree-remote-registry:fedora:ghcr.io/kuba86/fedora-coreos-bootc:stable"
        fedora_image="$(rpm-ostree status --booted --json | jq -r '.deployments[] | select(.booted) | .["container-image-reference"]')"
        
        if [[ "$fedora_image" == "$kuba86_image" ]]; then
          echo "kuba86 image already set"
        else
          echo "rebasing to kuba86 image"
          systemctl stop zincati.service && \
          rpm-ostree rebase "$kuba86_image" && \
          systemctl reboot
        fi
      register: fedora_coreos_bootc_rebase
      changed_when: "'rebasing to kuba86 image' in fedora_coreos_bootc_rebase.stdout"

```
