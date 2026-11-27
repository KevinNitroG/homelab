# Motrix

Motrix Server runs independently of the existing aria2 service. Its state is
stored in `motrix-data`; downloads go to `motrix-downloads`, also mounted at
`/srv/motrix` in File Browser. Both use local-path RWO storage, so the pods
must run on the same node. Back up the state PVC separately from downloads;
stop Motrix first for a consistent filesystem backup of its SQLite database.

## Authentication and first use

Motrix Server uses its own operator token, not OIDC. The gateway policy uses
the existing Authentik embedded outpost as a second authentication layer; no
separate oauth2-proxy is needed.

1. In Authentik, create a proxy provider in forward-auth mode and an application
   for the Motrix hostname, following the existing protected applications.
   Assign it to the embedded outpost. Configure both public and local hostnames
   using an appropriate provider for each, or use a suitable domain-level
   forward-auth configuration.
2. After Flux reconciles, confirm the gateway policy and certificate are ready
   and verify that unauthenticated requests are redirected to Authentik.
3. Retrieve the generated operator token privately:

   ```sh
   kubectl exec -n files deploy/motrix -- cat /data/operator-token
   ```

4. Sign in through Authentik, then unlock Motrix with the operator token.
   Do not share the token or commit it to Git.

The web UI is exposed over HTTPS on both configured hostnames. The MDXP port
for CLI and browser-extension pairing is not exposed; remote extensions are
disabled. Motrix's raw aria2 RPC remains on container loopback. The server is
not scaled to zero so downloads can continue without an open browser.

The Authentik policy applies at the gateway, not to direct in-cluster access.
The local-path PVCs are node-bound and their requested sizes are not necessarily
enforced as quotas. The deployment does not configure a backup.

See the [Motrix Server guide](https://www.motrix.app/manual/docker/) for
operator tokens, storage, security, and pairing.
