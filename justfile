age_key_file := '~/.age-key.txt'
encrypted_age_key := 'secret/encrypted_age.agekey'
age_key := 'secret/age.agekey'

default:
    @just --list

[unix]
tmuxinator:
    tmuxinator local

minikube profile='homelab':
    minikube start --cpus=4 --memory=12000 --profile={{ profile }}

age-encrypt-age own=age_key_file:
    age -i {{ own }} -e -o {{ encrypted_age_key }} {{ age_key }}

age-decrypt-age own=age_key_file:
    age -i {{ own }} -d -o {{ age_key }} {{ encrypted_age_key }}

add-age-cluster:
    kubectl create secret generic sops-age \
    --namespace=flux-system \
    --from-file={{ age_key }}

install-k3s:
    curl -sfL https://get.k3s.io | sh -

wol:
    wol -i 192.168.28.255 $KEVBLINK_MAC
