# Authentik embedded outpost: why protected apps returned 404

Investigated on November 24, 2026, on Authentik 2026.8.6. This is an incident note and recovery guide, not a record of a completed credential repair.

## What was broken?

Prometheus and Alertmanager were running, but their public URLs returned Authentik’s **Not found** page instead of redirecting to sign-in. This was not the same as the DbGate timeout: Istio reached Authentik, and the `404` response included `x-powered-by: authentik`. The failure happened at the authentication check, before Istio forwarded the original request to the app.

Alloy had **two** problems: it used the same broken authentication path, and Flux wasn’t deploying Alloy. Its manifests already defined `alloy-http`, `alloy-https`, and the Helm release, but the parent [monitoring Kustomization](../kubernetes/apps/monitoring/kustomization.yaml) didn’t include `./alloy.yaml`. Adding that entry wires both the routes and the backend into Flux. That change does not repair Authentik.

## Two credentials that must be different

| Credential | What it does | Where it lives |
| --- | --- | --- |
| `AUTHENTIK_SECRET_KEY` | A long-lived server secret used by Authentik. The embedded outpost also uses it to identify itself to Authentik’s internal API. | Authentik configuration. |
| `AUTHENTIK_BOOTSTRAP_TOKEN` | An optional first-install setting. It tells Authentik to create an API token for the default administrator, `akadmin`. It is not an outpost credential. | The setting is supplied in configuration; the created API token, named `authentik-bootstrap-token`, is stored in Authentik’s database. |

In this instance, **the stored `authentik-bootstrap-token` had the exact same value as `AUTHENTIK_SECRET_KEY`**. This was confirmed against the live database without printing either credential. The token belonged to `akadmin` and did not expire automatically.

## How a 403 inside Authentik turns into a 404 in your browser

1. The embedded outpost is part of the Authentik server. It periodically asks Authentik’s internal API, `GET /api/v3/outposts/proxy/`, for the list of proxy providers it should handle.
2. It sends `AUTHENTIK_SECRET_KEY` as its bearer credential. The Authentik API checks **stored API tokens first**, before trying the special secret-key authentication used by the embedded outpost.
3. Because the stored bootstrap token has the same value, the API matches it first and identifies the caller as **`akadmin`**, not as the outpost’s service account.
4. The provider-list API only accepts outpost service accounts. Even an administrator doesn’t qualify for this endpoint. The server logs showed `auth_via=api_token`, `user=akadmin`, and `status=403` on the outpost’s refresh requests.
5. The embedded outpost therefore never loads its provider list, even though Prometheus, Alertmanager, and Alloy are assigned to it in the database. When Istio asks the outpost to authenticate a browser request, the outpost has no loaded app for that hostname. The request falls through to Authentik core, which returns the `404` you see.

The two status codes refer to **different requests**: `403` is Authentik rejecting its own outpost’s provider refresh; `404` is the browser-facing symptom.

## Is this our configuration or an Authentik bug?

**Both, but there’s no need to wait for an upstream fix.** We supplied the same value for two different credentials. Authentik allows that configuration and silently picks the wrong identity when they match. [Upstream issue #26125](https://github.com/goauthentik/authentik/issues/26125) reports the same `akadmin`/`403`/browser `404` pattern. The token collision described here was verified on **this** instance; it shouldn’t be assumed for every report with the same symptoms.

Revoking or replacing the duplicate API token is a configuration repair, not an authentication bypass. With distinct credentials, Authentik can resolve the outpost’s identity as intended. Don’t grant extra permissions to `akadmin`, disable the gateway’s auth policy, or roll back Authentik just to avoid this check.

## Recovery

1. **Keep `AUTHENTIK_SECRET_KEY` unchanged for this repair.** Rotating it is a separate operation with effects on existing Authentik data and sessions. If the old bootstrap token was copied to another service or shared with anyone, that also exposed the server secret; plan a separate key rotation using Authentik’s version-specific guidance.
2. **Check whether anything actually uses `authentik-bootstrap-token`.** In the Authentik admin interface, look under **Directory → Tokens and App passwords** for that exact token. If an integration uses it, migrate the integration to an independently generated API token with only the access it needs, and verify the integration still works. Then revoke the old token. If it’s unused, revoke it directly. You’re revoking a token, not deleting `akadmin` or changing the admin password.
3. **Remove the bootstrap token from GitOps if it isn’t needed for new installs.** Remove the `bootstrap_token` setting from [Authentik’s Helm values](../kubernetes/apps/authentik/authentik/values.yaml) and the corresponding `AUTHENTIK_BOOTSTRAP_TOKEN` entry from the [SOPS-managed settings Secret](../kubernetes/apps/authentik/authentik-clustersettings.secret.sops.yaml). If a fresh installation really needs a bootstrap API token, use a separately generated value. Don’t decrypt or copy either credential into logs, chat, or Git.

**Why both changes?** The admin action fixes the **existing database record**. The GitOps change prevents a **future fresh install** from recreating the collision. Authentik skips bootstrapping an already configured instance, so changing or removing the environment variable by itself does not revoke or update the existing token.

## Verify the repair

Allow one refresh interval (about five minutes during this incident). No restart should be needed just to pick up the token revocation.

```bash
kubectl logs -n authentik deploy/authentik-server --since=10m |
  jq -Rc 'fromjson? |
    select((.event // "") | startswith("/api/v3/outposts/proxy/")) |
    {timestamp, status, user, auth_via}'
```

- **Before:** `status: 403`, `user: "akadmin"`, `auth_via: "api_token"`.
- **Expected after:** `status: 200`, an `ak-outpost-...` service account, and `auth_via: "secret_key"` on a new refresh.

Open [Prometheus](https://prometheus.kevinnitro.id.vn/) and [Alertmanager](https://alertmanager.kevinnitro.id.vn/) in a private browser window. Expect a sign-in redirect instead of the Authentik 404, then confirm each UI loads after signing in. For [Alloy](https://alloy.kevinnitro.id.vn/), also verify that Flux has deployed the routes **and** the backend:

```bash
kubectl get kustomization monitoring-alloy -n flux-system
kubectl get httproute alloy-http alloy-https -n monitoring
kubectl get svc alloy-alloy -n monitoring
kubectl get endpointslice -n monitoring \
  -l kubernetes.io/service-name=alloy-alloy
```

## References

- [Embedded outpost documentation](https://docs.goauthentik.io/add-secure-apps/outposts/embedded/) and [automated install settings](https://docs.goauthentik.io/install-config/automated-install/).
- Authentik 2026.8.6 source: [embedded client sends the secret key](https://github.com/goauthentik/authentik/blob/version/2026.8.6/packages/ak-common/src/api.rs), [API authentication checks stored tokens first](https://github.com/goauthentik/authentik/blob/version/2026.8.6/authentik/api/authentication.py), and [proxy provider list requires an outpost service account](https://github.com/goauthentik/authentik/blob/version/2026.8.6/authentik/providers/proxy/api.py).
