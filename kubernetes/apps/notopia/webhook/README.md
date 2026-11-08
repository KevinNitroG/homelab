# Notopia webhook provisioning

The Receiver is suspended and its token is deliberately absent. Before enabling it,
generate a strong token privately and create a SOPS-encrypted Secret in `flux-system`
named `notopia-webhook-token` with the key `token`. Add the encrypted file to this
directory's kustomization, commit it, and only then remove `spec.suspend` from the
Receiver. Never commit plaintext credentials. Configure a GitHub webhook for
`notopia-uit/notopia` with JSON content, push events, the same token as its secret,
and the Receiver's reported webhook path under
`https://flux-webhook.${PUBLIC_DOMAIN}/hook/`. Verify a ping and push after enabling.

The three Notopia Flux Kustomizations are also suspended independently: provision
the application credentials, compatible image tags and verify the edge security
boundary before enabling them in dependency order (infra, edge, apps). Consult the
Notopia homelab deployment runbook for the complete prerequisites and checks.
