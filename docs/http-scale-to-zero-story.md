# Story: Wake Web Apps on Demand

## Status

Considering only. No implementation or cluster changes have been requested.

## Goal

As a homelab user, I want selected web apps to scale their Deployments down to zero when idle and wake up when I visit them, so they use fewer resources when I am not using them.

Initial candidates:

| App | Namespace | Deployment |
| --- | --- | --- |
| File Browser | `files` | `filebrowser-filebrowser` |
| Redpanda Console | `redpanda` | `redpanda-console` |
| Kite | `kite` | `kite-kite` |
| Glance | `glance` | `glance-glance` |

The autoscaler should manage the Deployment, not individual pods or historical ReplicaSets. The Deployment manages its ReplicaSet and pods.

## Kubernetes built-in scaling

The cluster runs k3s Kubernetes 1.37.2. Kubernetes 1.37 enables the beta `HPAScaleToZero` feature by default, allowing an HPA to scale a workload between zero and a configured maximum when it uses a suitable object or external metric.

CPU and memory alone cannot wake an app from zero: no pods are running to provide those metrics. The signal must remain available independently of the app, and Kubernetes needs an adapter to expose it to the HPA. At the time of the initial check, the cluster exposed only the resource metrics API.

An HPA does not itself receive or buffer HTTP requests. A separate always-running component must detect a request and handle it while the app starts. Also, a Deployment manually scaled to zero may be treated as paused: the 1.37 HPA distinguishes its own scale-to-zero state from a manual pause.

Reference: [Kubernetes v1.37: Scale Workloads to Zero with HorizontalPodAutoscaler](https://kubernetes.io/blog/2026/09/02/kubernetes-v1-37-hpa-scale-to-zero-beta/).

## Reference: tuilakhanh/home-ops

The [zeroscaler component](https://github.com/tuilakhanh/home-ops/blob/master/kubernetes/components/zeroscaler/horizontalpodautoscaler.yaml) creates a 0–1 HPA using an external `probe_success` metric. Its default `nfs_probe` checks whether an NFS server is reachable; [Prometheus Adapter](https://github.com/tuilakhanh/home-ops/blob/master/kubernetes/apps/o11y/prometheus-adapter/app/helmrelease.yaml) exposes that metric to Kubernetes. The component is used by workloads such as [qBittorrent](https://github.com/tuilakhanh/home-ops/blob/master/kubernetes/apps/download/qbittorrent/ks.yaml).

This is a useful example of a reusable Flux component and external-metric HPA, but its default behavior follows **storage availability**, not web traffic. It does not provide request-triggered wake-up or buffer the first request. Copying it directly would not meet this story's goal.

## Suggested approach: KEDA HTTP add-on

Consider [KEDA and its HTTP add-on](https://github.com/kedacore/http-add-on), integrated with the existing Istio Gateway and HTTPRoutes. The HTTP add-on is beta. This approach uses KEDA's scaling integration rather than simply applying the native HPA example.

```text
Browser → Istio Gateway / existing authentication → HTTP interceptor
                                                       ↓
                                           wake sleeping Deployment
                                                       ↓
                                    wait for readiness and forward request
```

The interceptor must remain available when app replicas are zero. It observes HTTP traffic and can hold a request while the app starts. KEDA controls scaling based on HTTP activity; the initial request may take longer because of the cold start.

## Work to achieve the goal

1. Install KEDA and its HTTP add-on using the repository's Flux conventions.
2. Configure one app as a pilot, preferably File Browser, with a minimum of zero and maximum of one replica. Choose an idle cooldown; 15 minutes is a starting point to evaluate.
3. Route the app's existing hostnames through the interceptor. Preserve Istio Gateway behavior and Authentik authorization; configure any needed cross-namespace references and permissions.
4. Configure readiness and request timeouts so the interceptor can wait for the app and its storage to become ready. Check that Flux and Helm do not override the autoscaler's replica count.
5. Verify scale-down, wake-up, first-request behavior, authentication, and normal app use. Check that monitoring or background requests do not keep the app awake unintentionally.
6. Extend the tested pattern to Redpanda Console, Kite, and Glance.

File Browser transfers should be tested before relying on an HTTP idle signal: scaling down must not interrupt active work. Cold starts and an always-running interceptor are tradeoffs against the resources saved.

## Acceptance criteria

- Each selected Deployment scales to zero after its configured idle period and wakes when its URL is requested.
- The first request waits for the app to become ready and succeeds within the configured timeout.
- Existing public and local hostnames and applicable authentication continue to work.
- Flux and Helm reconciliation do not fight the autoscaler.
- Active use, including File Browser transfers, is not interrupted by idle scale-down.
- A repeatable test confirms both scale-down and wake-up for each selected app.

Downloaders and RustFS are outside the initial scope; HTTP inactivity alone does not establish that their background work is idle.
