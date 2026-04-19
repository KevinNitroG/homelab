# Homelab Kubernetes Structure Guide

This document provides a routing map of the Kubernetes directory structure for agents and developers to quickly understand the organization and find relevant components.

## Directory Overview

```
kubernetes/
├── app/              # Application deployments (databases, utilities)
├── cluster/          # Kustomization aggregation (main deployment target)
├── infrastructure/   # System infrastructure (configs, controllers)
└── monitoring/       # Observability stack (Prometheus, Grafana, Loki, Tempo, Alloy)
```

## Detailed Structure

### 1. `app/` - Application Layer

Container applications and databases. Uses **base/main pattern**.

```
app/
├── base/             # Base configurations (shared, reusable)
│   ├── cloudbeaver/  # Database GUI
│   ├── dbgate/       # Database management tool
│   ├── kite/         # App database (PostgreSQL with CNPG)
│   └── redis-commander/  # Redis UI
│
└── main/             # Main overlay (patches, customizations for prod)
    ├── cloudbeaver/
    ├── cloudflare-ddns/  # Dynamic DNS controller
    ├── dbgate/
    ├── kite/         # Kite app with recovery/backup config
    └── redis-commander/
```

**Key Pattern:**
- `base/` contains minimal, shared Kubernetes manifests
- `main/` contains kustomization patches and overlays for production deployment
- Database manifests often include CNPG (CloudNativePG) cluster definitions and backups

**Notable Files:**
- `base/kite/cnpg/kite.cluster.yaml` - PostgreSQL cluster definition
- `main/kite/cnpg/` - Recovery, backup, and plugin configuration patches

### 2. `cluster/` - Kustomization Aggregation Point

**This is where everything comes together for deployment.**

```
cluster/
├── dev/              # Development environment (stub, not actively used)
│
└── main/             # Production deployment target
    ├── kustomization.yaml  # Main aggregator (imports all overlays)
    ├── app/          # Import app overlay
    ├── infrastructure/    # Import infrastructure overlay
    ├── monitoring/   # Import monitoring overlay
    ├── flux-system/  # Flux configuration
    ├── namespace/    # Namespace definitions
    ├── setting/      # Cluster-wide settings
    └── ks/          # Additional kustomizations
```

**Key Concept:**
- `cluster/main/kustomization.yaml` is the **root kustomization** that aggregates all app, infrastructure, and monitoring overlays
- This is the primary target for `kubectl apply` or Flux reconciliation
- Changes to base configs propagate through this aggregation point

### 3. `infrastructure/` - System Infrastructure

System-level configurations and controllers. Uses **base/main pattern**.

```
infrastructure/
├── config/           # Global infrastructure configurations
│   ├── base/        # Base configs (ENV vars, secrets structure)
│   └── main/        # Production config overlays
│
└── controller/       # Kubernetes controllers (CNPG, operators)
    ├── base/        # Base controller manifests
    │   ├── authentik/    # Authentik app + PostgreSQL
    │   └── ...
    │
    └── main/        # Production controller patches
        ├── authentik/    # Authentik with backup/recovery setup
        └── ...
```

**Key Components:**
- `controller/base/authentik/cnpg/` - Authentik PostgreSQL cluster (CNPG)
- `controller/main/authentik/cnpg/` - Authentik backup, recovery, and plugin patches
- Each app may have PostgreSQL backups configured here (plugin method for Barman Cloud)

**Note on Backups:**
- All databases use `method: plugin` for backups (Barman Cloud plugin)
- ScheduledBackup objects reference the correct cluster names
- See "CNPG Backup Configuration" below for details

### 4. `monitoring/` - Observability Stack

Complete monitoring and observability infrastructure. Uses **base/main pattern**.

```
monitoring/
├── base/             # Base monitoring components
│   ├── alloy/        # Grafana Alloy (metrics/logs collection)
│   ├── grafana/      # Grafana dashboards + PostgreSQL (CNPG)
│   ├── kube-prometheus-stack/  # Prometheus + node-exporter
│   ├── loki/         # Log aggregation
│   ├── tempo/        # Distributed tracing
│   └── repository/   # Helm chart repositories
│
└── main/             # Production monitoring overlays
    ├── alloy/        # Alloy production config
    ├── grafana/      # Grafana with backup/recovery setup
    ├── kube-prometheus-stack/  # Production Prometheus patches
    ├── loki/         # Production Loki patches
    ├── tempo/        # Production Tempo patches
    └── repository/   # Repository configuration
```

**Key Components:**
- **Grafana Database**: PostgreSQL cluster `grafana-cnpg-grafana` with CNPG backups
- **Stack**: Prometheus (metrics), Loki (logs), Tempo (traces), Alloy (collection)

## Navigation Guide for Agents

### Finding Configuration

| Task | Location |
|------|----------|
| Add/modify an app | `app/base/[app-name]/` then patch in `app/main/[app-name]/` |
| Add infrastructure controller | `infrastructure/controller/base/[app]/` then overlay in `main/` |
| Configure database backup | `[location]/base/[app]/cnpg/*.cluster.yaml` and patches in `main/` |
| Modify monitoring stack | `monitoring/base/[component]/` then overlay in `monitoring/main/` |
| Deploy to production | Ensure `cluster/main/kustomization.yaml` includes all desired overlays |

### Base vs Main Pattern

**Base Configuration** (`base/`)
- Minimal, reusable Kubernetes manifests
- Should be environment-agnostic
- Contains the core definition (cluster, service, deployment)

**Main Overlay** (`main/`)
- Kustomization overlays and patches
- Production-specific customizations
- Recovery sources, backup plugins, environment variables
- Import and patch base configurations

**Example:**
```
base/kite/cnpg/kite.cluster.yaml         # Core PostgreSQL cluster
                                          # (1 instance, base storage)

main/kite/cnpg/kite.cluster.patch.yaml   # Patches: recovery source,
                                          # Barman Cloud plugin config
```

## CNPG Backup Configuration

All databases use the **plugin method** with Barman Cloud:

- **Method**: `plugin` (not `barmanObjectStore`)
- **Plugin**: `barman-cloud.cloudnative-pg.io`
- **Configuration Location**: 
  - Cluster patches: `[location]/main/[app]/cnpg/[app].cluster.patch.yaml`
  - ScheduledBackup: `[location]/main/[app]/cnpg/scheduledbackup.yaml`

**Important:** Old `barmanObjectStore` backups should be deleted. They fail because the cluster specs don't include the old backup section.

### Current Databases with CNPG:
- `authentik` (infrastructure/controller)
- `kite` (app)
- `grafana` (monitoring) - cluster name: `grafana-cnpg-grafana`

## Kustomization Flow

```
cluster/main/kustomization.yaml
├── imports: app/main/kustomization.yaml
│   ├── patches: app/base/cloudbeaver
│   ├── patches: app/base/dbgate
│   ├── patches: app/base/kite
│   └── ...
├── imports: infrastructure/main/kustomization.yaml
│   └── patches: infrastructure/controller/base/authentik
├── imports: monitoring/main/kustomization.yaml
│   ├── patches: monitoring/base/grafana
│   ├── patches: monitoring/base/kube-prometheus-stack
│   └── ...
└── global: cluster/main/namespace, cluster/main/setting
```

## Environment Variables & Secrets

- Infrastructure config base: `infrastructure/config/base/`
- Override in: `infrastructure/config/main/`
- Typically includes timezone, domain, credentials structure

## Quick Lookup

- **"Where is Kite configured?"** → `app/base/kite/` (base) and `app/main/kite/` (overlays)
- **"Where are backups defined?"** → `[app-location]/main/[app]/cnpg/scheduledbackup.yaml`
- **"How do I add monitoring?"** → `monitoring/base/[component]/` then patch in `monitoring/main/`
- **"What gets deployed?"** → `cluster/main/kustomization.yaml`
