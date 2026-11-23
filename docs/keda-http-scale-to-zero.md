# HTTP scale-to-zero with KEDA

This is the implementation record for [Wake Web Apps on Demand](http-scale-to-zero-story.md). Each app's Flux Kustomization manages its HTTP route, interceptor route, and ScaledObject together. HTTPS traffic is routed through the interceptor and scaling is enabled when the configuration is reconciled.

## How a request wakes an app

```text
Browser → Istio Gateway (TLS and existing authorization)
        → KEDA HTTP interceptor → original Service → ready app pod
                      │
                      └─ HTTP scaler → KEDA → Deployment
```

The interceptor stays up while the app sleeps. It counts in-flight requests, including the first waiting request, and forwards that request once the app has a ready endpoint. KEDA scales the **Deployment**, not a pod or an old ReplicaSet. Use a 0–1 replica range and a 5-minute idle cooldown. A long transfer can still count as activity even if it generates no new requests.

The design uses [KEDA 2.21.1](https://github.com/kedacore/keda/releases/tag/v2.21.1) and the [HTTP add-on 0.16.0](https://github.com/kedacore/http-add-on/releases/tag/v0.16.0), the latest stable releases checked on November 23, 2026. The HTTP add-on itself is still beta. Kubernetes HPA can scale to zero with suitable metrics, but it cannot wait on an HTTP request. The reference `probe_success` setup in the story signals storage availability, not user traffic. With KEDA, `minReplicas: 1` in the generated HPA is expected: KEDA handles the transitions between zero and one itself. This integration does not add a Prometheus Adapter or a manually configured HPA.

## What changed and why

- **Shared infrastructure:** `kubernetes/apps/keda/` installs core before the add-on in the `keda` namespace. The add-on uses one to four interceptor replicas, one scaler replica, and a limit of 100 cold-start requests per route per interceptor replica. It waits on ready endpoints and forwards through the original Service rather than bypassing it for a pod IP. Only the interceptor proxy Service (`keda-add-ons-http-interceptor-proxy:8080`) is referenced by the apps' cutover routes. A `ReferenceGrant` in `keda` authorizes those cross-namespace references; neither the scaler nor the administrative Service is exposed by those routes.
- **Scaling API:** Each app has an `http.keda.sh/v1beta1` `InterceptorRoute` and a `keda.sh/v1alpha1` `ScaledObject` using `external-push`, managed by the same Flux Kustomization. The old `HTTPScaledObject` is deprecated. The route matches the same public and local hostnames as the Gateway and targets the existing Service. [Upstream warns](https://keda.sh/http-add-on/0.16/user-guide/autoscale-an-app/) that KEDA can fall back to a CPU metric if it creates the scaler before the interceptor route exists; a CPU metric cannot wake the app from zero. A single Flux Kustomization does not guarantee that ordering, so verify the generated metric on initial deployment.
- **Ingress and auth:** Only the HTTPS backends change. Keep the original hostnames, Gateway listeners, HTTP redirects, and host header. File Browser's Authentik policy is still on the Gateway; the authenticated app request should be the one that reaches the interceptor.
- **Replica ownership:** File Browser and Glance already omit Deployment `spec.replicas`. The pinned Kite and Redpanda charts explicitly render `replicas: 1`; scoped Helm post-render patches remove that field from the two target Deployments so regular Helm upgrades do not declare it. A Helm drift-ignore rule by itself would not remove the field from upgrade manifests.
- **Schemas:** The YAML language-server directives use standalone JSON schemas. For the KEDA resources, the [Datree HTTP add-on schemas](https://github.com/datreeio/CRDs-catalog/tree/main/http.keda.sh) and [Datree KEDA schemas](https://github.com/datreeio/CRDs-catalog/tree/main/keda.sh) are editor aids; the OpenAPI schema in the pinned charts' CRDs is the version-specific source of truth.

| App | Service and readiness | Repo-specific change |
| --- | --- | --- |
| File Browser | `filebrowser-filebrowser:80`, `/health` | Adds an HTTP readiness probe. Bounds the wait for a ready endpoint without adding a short request or response-header deadline that could cut off transfers. |
| Redpanda Console | `redpanda-console:8080`, `/admin/health` | Sets `console.service.targetPort: 8080` because the pinned chart otherwise renders `targetPort: 0`. Adds the missing local hostname to the Istio certificate. Only Console scales; the broker does not. |
| Kite | `kite-kite:8080`, `/healthz` | Reuses the chart's probe and keeps the CNPG dependency. PostgreSQL stays up. |
| Glance | `glance-glance:8080`, `/api/healthz` | Reuses the existing probes. Moves File Browser and Kite from the Glance monitor to bookmarks. Their direct Service checks would report a sleeping app as down; pointing the checks at the interceptor would wake it instead. |

Expect the apps to start quickly once their containers can run, but do not treat the implementation language as a cold-start measurement. [Redpanda's broker](https://github.com/redpanda-data/redpanda) is mainly **C++**, but the target is [Console](https://github.com/redpanda-data/console), a Go backend with a TypeScript/React frontend. [Kite](https://github.com/kite-org/kite) is also Go with a React UI; [Glance](https://github.com/glanceapp/glance) is Go with templates and JavaScript, not React; [File Browser](https://github.com/filebrowser/filebrowser) uses Go and a Vue frontend. Image pulls, scheduling, PVC mounts, database connections, and endpoint propagation can dominate a cold start regardless.

## Deployment checks

1. Check that both KEDA releases, the `ReferenceGrant`, each app's `InterceptorRoute`, and each app are ready. The app Kustomizations depend on KEDA and the grant, but apply the route and ScaledObject together.
2. For each app, verify the generated HPA uses the HTTP scaler's external metric rather than CPU before relying on scale-to-zero. If it uses CPU, investigate and correct the ScaledObject/HPA after confirming the interceptor route exists.
3. Test both hostnames, including Authentik for File Browser. The ScaledObjects use `cooldownPeriod: 300` and omit `initialCooldownPeriod`, allowing immediate scale-down if no activity has been recorded. File Browser keeps its `90s` readiness budget and disabled request timeouts; the other apps use a `30s` interceptor readiness budget, `60s` interceptor request budget, and `75s` Gateway request budget.
4. If rolling an active autoscaled app back to direct routing, first set its `minReplicaCount` to `1` and verify a ready backend, then restore the direct route and remove the `ScaledObject`.

## Offline verification

The initial staged configuration was validated offline against the pinned CRDs and rendered charts. The current single-Kustomization configuration requires fresh verification, including the live checks below.

## What still needs a live test

Start with **File Browser** before adopting the same settings everywhere. For each app, let it fall to zero without hitting its hostname, then make a real request through each hostname. Verify that the first request succeeds without a reload, the Deployment goes to one, and it returns to zero after traffic stops. The interceptor's `X-KEDA-HTTP-Cold-Start` response header can help distinguish a wake from a warm request.

Check these in particular:

- **Kubernetes compatibility:** KEDA 2.21's [published test matrix](https://keda.sh/docs/2.21/operate/cluster/#kubernetes-compatibility) covers Kubernetes 1.34–1.36, not the story's k3s 1.37.2. The charts accept 1.37.2 for offline templating; that is not an upstream compatibility guarantee. Verify the aggregated metrics API and controller behavior on 1.37 before trusting the integration.
- The generated HPA uses the HTTP scaler's **external** metric, not CPU. A reconciled `InterceptorRoute` alone does not prove that the data path works.
- The authenticated File Browser request succeeds from zero; an unauthenticated request still gets the expected Authentik flow. Both hostnames present valid TLS, including Redpanda after the local certificate is reissued.
- A slow File Browser upload and download that each last more than 5 minutes remain active. Check both hostnames: the Gateway, application, and interceptor can each impose separate limits. If the public hostname is proxied through Cloudflare, its [connection timeouts](https://developers.cloudflare.com/fundamentals/reference/connection-limits/) and [upload-size limits](https://developers.cloudflare.com/support/troubleshooting/http-status-codes/4xx-client-error/error-413/) also apply; changing the YAML here cannot remove those limits. Concurrency protects tracked requests from idle scale-down, not from proxy restarts or network failures.
- Flux reconciles while apps are at zero, and a Helm upgrade does not take replica ownership back. Test the first upgrade of the existing Kite and Redpanda releases separately from later upgrades.
- Background polling, new tabs, persistent connections, and health checks don't unexpectedly keep an app awake. If required background work is not tied to an open HTTP request, HTTP idleness alone cannot protect it.
- Measure cold-start latency on the public and local paths with cached images and image pulls, and compare the resources saved against the always-running KEDA components. The readiness budgets and cold-start queue limit are starting points, not measured capacity.
