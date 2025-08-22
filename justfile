mod mltb './kubernetes/apps/mltb'

default:
  @just --list

[unix]
tmuxinator:
  tmuxinator local

minikube profile='homelab':
  minikube start --cpus=4 --memory=12000 --profile={{profile}}

age-encrypt-age own='~/.age-key.txt':
  age -i {{own}} -e -o secrets/encrypted_age.agekey secrets/age.agekey

age-decrypt-age own='~/.age-key.txt':
  age -i {{own}} -d -o secrets/age.agekey secrets/encrypted_age.agekey

add-age-cluster:
  kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=./secrets/age.agekey
