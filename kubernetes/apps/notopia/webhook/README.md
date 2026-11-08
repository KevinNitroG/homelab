# Notopia webhook provisioning

The Receiver is suspended and its token is deliberately absent. Before enabling it,
generate a strong token privately and create a SOPS-encrypted Secret in `flux-system`
named `notopia-webhook-token` with the key `token`. Add the encrypted file to this
directory's kustomization, commit it, and only then remove `spec.suspend` from the
Receiver. Never commit plaintext credentials. Configure a GitHub webhook for
`notopia-uit/notopia` with JSON content, push events, the same token as its secret,
and a URL formed by appending the Receiver's reported webhook path directly to
`https://flux-webhook.${PUBLIC_DOMAIN}`. The reported path already starts with
`/hook/`; do not add that prefix again. Verify a ping and push after enabling.

The three Notopia Flux Kustomizations are also suspended independently: provision
the application credentials, compatible image tags and verify the edge security
boundary before enabling them in dependency order (infra, edge, apps). Consult the
Notopia homelab deployment runbook for the complete prerequisites and checks.

The checked-in Istio configuration enables the ambient profile for istiod, CNI,
and ztunnel, but does not demonstrate how existing namespaces are enrolled or
prove that traffic is intercepted. The Notopia namespace has no explicit ambient
enrollment label; its actual enrollment is unknown. Before enabling any pointer,
verify the live cluster's enrollment
mechanism and, if compatible, add `istio.io/dataplane-mode: ambient` to the
namespace in Git. Confirm that workloads are captured and that the intended edge
and workload authorization policies enforce the boundary using an independently
provisioned test workload and policies; do not rely on a label alone as evidence
of enforcement. Keep the pointers suspended until these checks and the other
deployment prerequisites are satisfied. After deployment, verify capture and policy
enforcement for the actual Notopia workloads before allowing public traffic.
