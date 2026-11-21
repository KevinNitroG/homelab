# K3s certificate and kubeconfig renewal

This guide covers the `kevblink` K3s server and the kubeconfig on the workstation. It does not cover application certificates managed by cert-manager.

## Current dates

Checked on November 21, 2026:

| Certificate | Expiry | Action |
| --- | --- | --- |
| API server serving certificate | November 21, 2027 | No renewal needed now. |
| Admin client certificate, including the workstation's copied credentials | July 27, 2027 | Check and refresh the workstation copy before expiry. |
| K3s client and server CA certificates | July 24, 2036 | Plan CA rotation separately; it is not automatic. |

Dates change when certificates are renewed. Check the live values rather than relying on this table. The API server certificate currently includes `kubernetes.kevinnitro.id.vn`.

## How renewal works

K3s client and server certificates normally last 365 days. On K3s startup, certificates that have expired or have 120 days or less remaining are automatically renewed. A continuously running server will not renew them until K3s starts again. K3s also raises a `CertificateExpirationWarning` event when a certificate enters that window.

K3s renews its own files, but **does not update kubeconfig files copied to other machines**. Both `kevblink` and `kevblink-local` on this workstation currently contain their own embedded copies of the admin client certificate and key. Refresh both after the server's admin certificate is renewed and before the workstation copies expire.

For the current admin certificate, the 120-day window begins around **March 29, 2027**. Check during that window, plan a K3s restart if it has not restarted, then refresh the workstation copies. Restarting the only server interrupts the Kubernetes API and may disrupt workloads.

CA certificates have a different lifecycle: K3s-generated CAs last about 10 years and are not automatically renewed. CA rotation is a separate, potentially disruptive procedure; do not use it for routine client or server certificate renewal.

## Check expiration

From the workstation, check the server certificates:

```bash
ssh kevblinklocal 'sudo k3s certificate check --output table'
```

Check the workstation's two embedded client certificates:

```bash
for user in kevblink kevblink-local; do
  printf '\n%s\n' "$user"
  kubectl config view --raw -o json |
    jq -er --arg user "$user" '.users[] | select(.name == $user) | .user["client-certificate-data"]' |
    base64 -d |
    openssl x509 -noout -subject -dates
done
```

`kubectl config view --raw` includes private credentials. Do not print its complete output or share it.

## Renew the server certificates

The repository also provides `ansible/playbooks/k3s-renew-kubeconfig.yml` to
check the admin certificate and refresh this workstation's two kubeconfig
users. From the `ansible/` directory, run:

```bash
ansible-playbook playbooks/k3s-renew-kubeconfig.yml
```

The inventory uses `192.168.28.25`. If the workstation is outside that LAN
but public SSH is available, override the address for this run:

```bash
ansible-playbook playbooks/k3s-renew-kubeconfig.yml -e ansible_host=ssh.kevinnitro.id.vn
```

If the certificate is within 120 days of expiry, the playbook stops without
restarting K3s. During an approved maintenance window, allow the restart with:

```bash
ansible-playbook playbooks/k3s-renew-kubeconfig.yml -e k3s_allow_restart=true
```

It backs up the kubeconfig if credentials change and removes temporary credential
files. It uses `~/.kube/config` on the machine running Ansible and requires
both `kevblink` and `kevblink-local` users to exist. It does not rotate CAs or
update trusted CA data. The manual steps below are an alternative.

If the admin certificate is within 120 days of expiry, arrange a maintenance window and restart K3s:

```bash
ssh kevblinklocal 'sudo systemctl restart k3s'
```

Wait for K3s to come back, then check:

```bash
ssh kevblinklocal 'sudo systemctl is-active k3s'
ssh kevblinklocal 'sudo k3s certificate check --output table'
kubectl --context=kevblink-local get nodes
```

Confirm that `client-admin.crt` has a new expiry before refreshing the workstation. If it has not changed, investigate the K3s logs before continuing:

```bash
ssh kevblinklocal 'sudo journalctl -u k3s -n 100 --no-pager'
```

A restart outside the 120-day window does not necessarily renew an otherwise valid certificate. Manual rotation is a separate operation; follow the official K3s documentation if it is required.

## Refresh the workstation kubeconfig

Run this on the workstation after K3s has renewed `client-admin.crt`. It fetches the K3s-generated admin kubeconfig over SSH, embeds its client certificate and key into the two existing users, and leaves their server addresses and contexts unchanged. It assumes the kubeconfig is `~/.kube/config`, the K3s file has its standard `default` user, and `jq`, `kubectl`, and `openssl` are installed.

The admin credential grants cluster-wide administrative access. Use a trusted workstation, do not share the files or command output, and protect the backup as carefully as the original.

First authenticate sudo on the server if needed:

```bash
ssh -t kevblinklocal 'sudo -v'
```

Then run this entire block in Bash:

```bash
(
  set -euo pipefail
  umask 077
  dir=$(mktemp -d)
  trap 'rm -f "$dir/k3s.yaml" "$dir/client.crt" "$dir/client.key"; rmdir "$dir"' EXIT

  ssh kevblinklocal 'sudo -n cat /etc/rancher/k3s/k3s.yaml' > "$dir/k3s.yaml"
  kubectl --kubeconfig "$dir/k3s.yaml" config view --raw -o json |
    jq -er '.users[] | select(.name == "default") | .user["client-certificate-data"]' |
    base64 -d > "$dir/client.crt"
  kubectl --kubeconfig "$dir/k3s.yaml" config view --raw -o json |
    jq -er '.users[] | select(.name == "default") | .user["client-key-data"]' |
    base64 -d > "$dir/client.key"

  openssl x509 -in "$dir/client.crt" -noout -subject -dates -checkend 10368000
  backup="$HOME/.kube/config.backup.$(date +%Y%m%d-%H%M%S)"
  cp -p "$HOME/.kube/config" "$backup"
  chmod 600 "$backup"
  printf 'Protected kubeconfig backup: %s\n' "$backup"

  for user in kevblink kevblink-local; do
    kubectl --kubeconfig "$HOME/.kube/config" config set-credentials "$user" \
      --client-certificate="$dir/client.crt" \
      --client-key="$dir/client.key" \
      --embed-certs=true
  done
)
```

The certificate check requires more than 120 days remaining; if it fails, the kubeconfig is not modified. If sudo authentication expires between commands, rerun the `sudo -v` command and retry. The temporary files are removed on exit; the protected backup remains until you deliberately remove it.

Recheck the workstation certificate dates using the commands above, then test locally:

```bash
kubectl --context=kevblink-local get nodes
```

Once public DNS and router forwarding are configured, test the remote context from outside the home network:

```bash
kubectl --context=kevblink get nodes
```

The remote context uses `https://kubernetes.kevinnitro.id.vn:6443`; the local context uses `https://192.168.28.25:6443`. The current server certificate covers both names. If the CA changes in a future CA rotation, refreshing only the client credentials is insufficient: update the trusted CA data in each cluster entry as part of that rotation.

## References

- [K3s certificate management](https://docs.k3s.io/cli/certificate)
- [K3s cluster access and kubeconfig](https://docs.k3s.io/cluster-access)
