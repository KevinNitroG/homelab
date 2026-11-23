# Capacitor

Flux manages the release in the `capacitor` namespace. Istio serves it at
`https://capacitor.${PUBLIC_DOMAIN}` with the existing public wildcard certificate.
The release starts suspended.

| Authentik group | Kubernetes access |
| --- | --- |
| `Capacitor Viewers` | Read-only Flux status and events. Uses a narrower role than the upstream read-only preset, which can read ConfigMaps. |
| `Capacitor Editors` | Upstream editor preset: reconcile and modify Flux resources, edit workloads, read Secrets, and use exec or port-forward. Not reconcile-only. |
| `Capacitor Admins` | Upstream cluster-admin preset: unrestricted cluster access. |

Only grant editor or admin to trusted operators. A compromise of the public
Capacitor process or its service-account token can reach cluster-admin via
impersonation even if no user is assigned to the Authentik admin group.

## Before enabling the release

1. Get a valid self-hosting beta license from [Gimlet](https://gimlet.io/capacitor-next/).
   The chart is publicly downloadable, but the pinned image refuses to start
   without `LICENSE_KEY`. The free Apache-licensed local CLI is a separate mode.
2. In Authentik, create the groups above and add the intended users.
   Create an application with slug `capacitor` and a confidential OAuth2/OIDC
   provider with client ID `capacitor`, per-provider issuer mode, and an
   asymmetric signing key. Use authorization code flow and register the exact
   redirect URI `https://capacitor.<public-domain>/auth/callback`. Bind application
   access to any of the three groups using policy engine mode **Any**.
3. Enable **Include claims in ID token** and attach the standard email mapping.
   Replace the standard `profile` scope
   mapping for **this provider only** with a `profile` scope mapping that emits
   only the Capacitor groups:

   ```python
   return {
       "groups": [
           group.name
           for group in request.user.groups.filter(
               name__in=["Capacitor Viewers", "Capacitor Editors", "Capacitor Admins"]
           )
       ],
   }
   ```

   Verify the ID token contains the expected `email` and
   the expected Capacitor group names for an approved user. Don't attach a second
   mapping that emits all Authentik groups: Kubernetes will reject requests
   attempting to impersonate any other group.
4. Replace `CAPACITOR_ALLOWED_EMAIL` in [`../capacitor.yaml`](../capacitor.yaml)
   with the initial user's exact email. To add more users, use a comma-separated
   `AUTHORIZED_EMAILS` value **and** add a separate Kubernetes `resourceNames`
   entry for each email in the Helm post-render patch. Group membership grants
   the role; the email list limits which users the runtime identity can
   impersonate. Use accounts without independent privileged Kubernetes bindings.
5. From the repository root, run
   `sops edit kubernetes/apps/capacitor/capacitor.secret.sops.yaml` and fill
   `OIDC_CLIENT_SECRET` and `LICENSE_KEY`. Session keys are already generated.
   Verify public DNS and confirm the pod can reach Authentik discovery and token
   endpoints over verified HTTPS. Remove `spec.suspend: true` from the HelmRelease
   once those prerequisites are met.

## After reconciliation

Check the OCI source, HelmRelease, Deployment, and HTTPRoute. Confirm an
unauthenticated browser gets no cluster data and an unapproved user cannot sign
in. Test that a viewer can see Flux status and events but cannot read Secrets
or ConfigMaps, exec, port-forward, or reconcile. With an editor account, test
reconciliation on a noncritical release.

After changing the Secret, restart the Deployment so it reloads environment
variables and the mounted registry file. To cut public access, remove the
`HTTPRoute` resources from Kustomize; suspending Helm alone won't stop a running
release or remove its route.
