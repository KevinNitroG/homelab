default:
  @just --list

[unix]
tmuxinator:
  tmuxinator local

minikube profile='homelab':
  minikube start --cpus=4 --memory=12000 --profile={{profile}}

age-encrypt-age own='~/.age-key.txt':
  age -i {{own}} -e -o secret/encrypted_age.agekey ecrets/age.agekey

age-decrypt-age own='~/.age-key.txt':
  age -i {{own}} -d -o secret/age.agekey secret/encrypted_age.agekey

add-age-cluster:
  kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=./secret/age.agekey

wol:
  wol -i 192.168.28.255 $KEVBLINK_MAC
