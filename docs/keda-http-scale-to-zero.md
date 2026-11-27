# HTTP scale-to-zero with KEDA

This document records the implementation of [Wake Web Apps on Demand](http-scale-to-zero-story.md). Each app's Flux Kustomization manages its HTTPS route, interceptor route, and ScaledObject together.

**Verification status:** The initial staged configuration passed offline validation against the pinned CRDs and rendered charts. The current single-Kustomization configuration needs fresh offline and live verification. DbGate is configured in Git, but its rollout and verification are pending; an earlier cluster check found neither its Flux Kustomization nor its workload.

## How it works

```text
Browser → Istio Gateway (TLS and existing authorization)
        → KEDA HTTP interceptor → original Service → ready app pod
                      │
                      └─ HTTP scaler → KEDA → Deployment
```

The interceptor stays running and counts in-flight requests. When an app is at zero, it holds the first request until a ready endpoint is available, then forwards it through the original Service. An open transfer counts as activity; pauses between requests do not.

Each app scales between zero and one Deployment replica, with a 300-second idle cooldown. The generated HPA may show `minReplicas: 1`: KEDA handles the zero-to-one transition. The ScaledObjects omit `initialCooldownPeriod`, so an app can scale down immediately if no activity has been recorded. No Prometheus Adapter or manually configured HPA is involved.

The design uses [KEDA 2.21.1](https://github.com/kedacore/keda/releases/tag/v2.21.1) and [HTTP add-on 0.16.0](https://github.com/kedacore/http-add-on/releases/tag/v0.16.0), the latest stable releases checked on November 23, 2026. The HTTP add-on is still beta. The story's `probe_success` example measures storage availability, not user traffic; an HPA alone cannot hold a request while an app starts.

## Configuration

### Shared infrastructure

`kubernetes/apps/keda/` installs KEDA before the HTTP add-on in the `keda` namespace. The add-on runs one to four interceptor replicas and one scaler replica. Each interceptor queues up to 100 cold-start requests per route.

App HTTPS routes reference only `keda-add-ons-http-interceptor-proxy:8080`. A `ReferenceGrant` in `keda` permits cross-namespace references; the routes do not expose the scaler or administrative Service. Hostnames, Gateway listeners, HTTP redirects, host headers, and Gateway authorization policies remain unchanged.

Each app has an `http.keda.sh/v1beta1` `InterceptorRoute` for its public and local hostnames and a `keda.sh/v1alpha1` ScaledObject using `external-push`. The route targets the existing Service. The older `HTTPScaledObject` is deprecated.

**Check the generated HPA metric on initial deployment.** Flux applies the route and ScaledObject in the same Kustomization but does not guarantee their order. If the scaler is created before the route exists, [KEDA may fall back to a CPU metric](https://keda.sh/http-add-on/0.16/user-guide/autoscale-an-app/), which cannot wake an app from zero.

File Browser and Glance Deployments omit `spec.replicas`. The pinned Kite and Redpanda charts render `replicas: 1`, so scoped Helm post-render patches remove it from those Deployments. A drift-ignore rule alone would not remove it from upgrade manifests.

YAML language-server directives use standalone JSON schemas. The [Datree HTTP add-on](https://github.com/datreeio/CRDs-catalog/tree/main/http.keda.sh) and [KEDA](https://github.com/datreeio/CRDs-catalog/tree/main/keda.sh) schemas are editor aids; the pinned charts' CRD OpenAPI schemas are the version-specific source of truth.

### Apps

| App | Service | Readiness | Notes |
| --- | --- | --- | --- |
| File Browser | `filebrowser-filebrowser:80` | `/health` | Adds a readiness probe. Authentik remains on the Gateway. |
| Redpanda Console | `redpanda-console:8080` | `/admin/health` | Sets `console.service.targetPort: 8080`; the pinned chart otherwise renders `0`. Adds the local hostname to the Istio certificate. The broker stays running. |
| Kite | `kite-kite:8080` | `/healthz` | Uses the chart's probe and retains its CNPG dependency. PostgreSQL stays running. |
| Glance | `glance-glance:8080` | `/api/healthz` | Uses existing probes. File Browser and Kite move from the monitor to bookmarks: direct Service checks report sleeping apps as down, while interceptor checks wake them. |
| DbGate | `dbgate-dbgate:3000` | `/health` | Configured in Git; rollout pending. See below. |

File Browser and DbGate use a `90s` interceptor readiness budget, with total request deadlines disabled at the interceptor and Gateway. This bounds startup without imposing a short lifetime on transfers or DbGate's `/stream` connection. The other apps use `30s` readiness, `60s` interceptor request, and `75s` Gateway request budgets.

### DbGate

The app list includes `./dbgate/`, and the KEDA proxy `ReferenceGrant` permits `dbgate`. Its Flux Kustomization depends on `default-gatewayapi`, `keda-http`, and `keda-grant`, using the same KEDA health-check expressions as Glance.

The Deployment omits `spec.replicas`. The pinned [`dbgate/dbgate:7.3.6-alpine` image serves `/health`](https://github.com/dbgate/dbgate/blob/v7.3.6/packages/api/src/main.js). Its interceptor route matches both hostnames, and its ScaledObject targets Deployment `dbgate-dbgate`. Only HTTPS uses the interceptor. Gateway Authentik remains in place, while DbGate itself has `SKIP_ALL_AUTH` enabled.

DbGate remains in the Glance monitor without a separate `check-url`. Verify whether the monitor checks its main URL and wakes it or keeps it awake.

## Verification

Start with File Browser. Repeat the following for each app before relying on scale-to-zero:

1. Confirm both KEDA releases, the `ReferenceGrant`, the app's `InterceptorRoute`, and the app are ready.
2. Confirm the generated HPA uses the HTTP scaler's **external** metric, not CPU. If it uses CPU, confirm the route exists, then investigate and correct the ScaledObject/HPA. A reconciled route alone does not prove the data path works.
3. Let the app reach zero without visiting its hostname. Request each public and local hostname. Confirm the first request succeeds without a reload, the Deployment reaches one replica, and it returns to zero after traffic stops. The `X-KEDA-HTTP-Cold-Start` response header can distinguish a cold start from a warm request.
4. Verify TLS on both hostnames, including Redpanda's local hostname after certificate reissue. Test authenticated and unauthenticated File Browser requests from zero, and verify DbGate's Authentik flow.
5. Confirm Flux reconciliation at zero and that Helm upgrades do not reclaim replica ownership. Test the first upgrade of existing Kite and Redpanda releases separately from subsequent upgrades.
6. Check whether background polling, new tabs, persistent connections, or health checks prevent scale-down. HTTP idleness cannot protect required background work that is not tied to an open request.
7. Measure request-to-ready latency on both paths with cached images and image pulls. Scheduling, PVC mounts, database connections, and endpoint propagation also affect startup. Compare savings with the always-running KEDA components; readiness budgets and queue limits are unmeasured starting points.

### Compatibility and long-running requests

- **Kubernetes:** KEDA 2.21's [test matrix](https://keda.sh/docs/2.21/operate/cluster/#kubernetes-compatibility) covers Kubernetes 1.34–1.36, not the story's k3s 1.37.2. Successful offline chart templating is not a compatibility guarantee. Verify the aggregated metrics API and controller behavior on 1.37.
- **File Browser transfers:** Test uploads and downloads lasting more than five minutes on both hostnames. Gateway, application, and interceptor limits are separate. A Cloudflare-proxied hostname also has [connection timeouts](https://developers.cloudflare.com/fundamentals/reference/connection-limits/) and [upload-size limits](https://developers.cloudflare.com/support/troubleshooting/http-status-codes/4xx-client-error/error-413/) that these manifests cannot remove. Concurrency protects tracked requests from idle scale-down, not proxy restarts or network failures.
- **Chunked uploads:** Concurrency does not protect pauses between TUS chunks. The pinned File Browser build uses an in-memory upload cache without Redis; a PVC may retain partial data but not upload metadata. If resume across scale-down is required, test a pause longer than the cooldown and consider [Redis-backed metadata](https://github.com/filebrowser/filebrowser/blob/v2.63.23/cmd/root.go).
- **DbGate:** Test whether an idle tab keeps it awake and what happens to a long-running query when the client disconnects.

## Rollback

Before restoring direct routing for an active autoscaled app, set `minReplicaCount` to `1` and verify a ready backend. Then restore the direct route and remove the ScaledObject.

## Apps not adopted

### Authentik

Keep the server and worker running. Istio sends authorization checks directly to the [embedded outpost](https://docs.goauthentik.io/add-secure-apps/outposts/embedded/) inside the server. Routing only the Authentik website through KEDA would not wake authorization for protected apps.

A future design would need to route authorization checks through the interceptor, preserve host and path, avoid route conflicts, and fail closed. It must also account for direct API and OIDC callers, which cannot wake the server through direct calls. This design is untested and not planned.

If revisited, coordinate a measured, bounded readiness wait with Istio authorization, Gateway, client, and Cloudflare timeouts. The existing `/-/health/ready/` probe and roughly 10-minute startup probe do not establish cold-start time. Never use a loading placeholder as an authorization decision. Remove `spec.replicas` only from the server's rendered Deployment; the worker and PostgreSQL must remain running. Glance checks can either report a sleeping server as down or wake it. A possible 900-second cooldown is not an exact shutdown time, and background traffic or persistent connections can extend it.

Test login and protected requests from zero for authenticated and unauthenticated users, all hostnames and direct callers, fail-closed behavior, cached and uncached starts, Helm and Flux reconciliation, and eventual scale-down. One snapshot showed about 415 MiB RAM for the server; the worker and database would remain up.

### Grafana

Keep one replica. Grafana Operator 5.26.0 scales the Grafana custom resource, not its operator-owned Deployment. The live `/scale` endpoint returned HTTP 500 because `spec.deployment.spec.replicas` was absent. Even if that field were seeded and handed off from GitOps, the [pinned operator](https://github.com/grafana/grafana-operator/blob/v5.26.0/controllers/reconcilers/grafana/complete_reconciler.go#L25-L48) treats a sleeping instance as failed and defers dashboard, datasource, and folder synchronization.

Grafana-managed alert evaluations would stop; independent Prometheus and Alertmanager would not. One snapshot showed Grafana using about 147 MiB and 16 millicores; PostgreSQL and the operator would remain running. The savings do not justify the complexity.

### MeTube

Skip KEDA. A live snapshot showed its Deployment at zero, with no ScaledObject and a direct HTTPS backend. It had no HTTP wake path, so this was not a working scale-to-zero setup.

If revisited, HTTP concurrency could wake MeTube, while a second trigger on the same ScaledObject could use a Prometheus gauge from its internal [`/history` queue](https://github.com/alexta69/metube/blob/2026.11.14/app/main.py) to keep it awake. Count runnable queued work, downloads, and post-processing, not completed or manually pending items. Missing telemetry from a running pod is not evidence of idleness. Subscriptions and scheduled livestreams require an always-running process or external wake mechanism. No exporter or autoscaler is planned.
