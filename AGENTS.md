# Homelab Repository Guide

This repository manages a homelab environment with two primary infrastructure layers: **Kubernetes** (Flux-managed) and **Ansible** (configuration management).

## Repository Structure

```
homelab/
├── kubernetes/       # Flux GitOps-managed K8s workloads (apps, cluster, components)
├── ansible/          # Ansible playbooks and roles for host configuration
├── config/           # Shared configuration files
├── secret/           # Encrypted secrets (SOPS)
├── submodules/       # Git submodules
└── agents/           # Agent skills (e.g., kubernetes-guidance)
```

## Available CLI Tools

The following tools are available for interacting with this homelab:

| Tool | Purpose | Use Case |
|------|---------|----------|
| `kubectl` | Kubernetes API | Direct cluster queries, resource inspection |
| `flux` | Flux CD CLI | Reconcile sources, check Flux status, force reconciliation |
| `cmctl` | cert-manager CLI | Inspect certificates, issuers, cert-manager health |
| `kubectl-cnpg` | CloudNativePG plugin | CNPG cluster status, backups, timeline |
| `ansible` | Configuration management | Host provisioning, system config, package management |
| `renovate` | Dependency updates | Update Helm chart versions, container images |
| `sops` | Secret encryption | Encrypt/decrypt SOPS-encrypted files |

## Kubernetes (Flux GitOps)

For detailed Kubernetes structure, apps, Flux configuration, and how to add/modify workloads, see the **kubernetes-guidance** skill.

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
sops decrypt <file>.sops.yaml    # View decrypted content
sops encrypt -i <file>.yaml      # Encrypt in-place
sops <file>.sops.yaml            # Edit (decrypt → $EDITOR → re-encrypt)
```
