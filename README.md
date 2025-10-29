# KevinNitro's Homelab

![Uptime Robot status](https://img.shields.io/uptimerobot/status/m801664720-cfdf48c08ed1816b35a48879?style=for-the-badge)

### NOTE

- Ensure those environment variables are set:
  - `GH_TOKEN`

### Bootstrap

- `/etc/rancher/k3s/config.yaml`
  ```yaml
  write-kubeconfig-mode: "0644"
  disable:
    - traefik
  tls-san:
    - kev
    - kevinnitro.id.vn
  node-label:
    - "role=master"
  # default-local-storage-path: "/home/kevinnitro/k3s-storage"
  ```

> [!WARNING]
> local path provisioner doesn't care about storage limit

### Acknowledge

- <https://github.com/tuilakhanh/home-ops>
