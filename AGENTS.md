# Homelab Repository Guide

This repository manages a homelab environment

## Repository Structure

```
homelab/
├── kubernetes/       # Flux GitOps-managed K8s workloads (apps, cluster, components)
├── ansible/          # Ansible playbooks and roles for host configuration
└── secret/           # Encrypted secrets (SOPS)
```

## Available CLI Tools

The following tools are available for interacting with this homelab:

| Tool           | Purpose                  |
| -------------- | ------------------------ |
| `kubectl`      | Kubernetes API           |
| `flux`         | Flux CD CLI              |
| `cmctl`        | cert-manager CLI         |
| `kubectl-cnpg` | CloudNativePG plugin     |
| `ansible`      | Configuration management |
| `renovate`     | Dependency updates       |
| `sops`         | Secret encryption        |

## Kubernetes

For detailed Kubernetes structure, apps, Flux configuration, and how to add/modify workloads, see the **kubernetes-guidance** skill, and sync the cluster manifest changes with the skill content.

Quick reference:

- Flux root: `cluster/flux-system/gotk-sync.yaml`
- Apps: `kubernetes/apps/`
- Namespaces: `kubernetes/cluster/namespaces.yaml`
- Shared config: `kubernetes/components/clustersettings/`

## Ansible

Ansible playbooks and roles are in the `ansible/` directory. Use for host-level configuration, package management, system users, and infrastructure provisioning outside of Kubernetes.

## SOPS Secrets

This repo uses `sops` with age encryption. Encrypted files match `.sops.yaml` patterns:

- `kubernetes/.*\.sops\.ya?ml` — K8s secrets (`data`/`stringData` encrypted)
- `kubernetes/.*values\.sops\.ya?ml` — Helm values (entire file encrypted)

```bash
sops decrypt <file >.sops.yaml # View decrypted content
sops encrypt -i <file >.yaml   # Encrypt in-place
sops <file >.sops.yaml         # Edit (decrypt → $EDITOR → re-encrypt)
```

## Rules

- Use conventional commit
