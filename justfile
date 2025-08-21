mod mltb './kubernetes/apps/mltb'

set dotenv-required
set dotenv-load

default:
  @just --list

[unix]
tmuxinator:
  tmuxinator local

minikube profile='homelab':
  minikube start --cpus=4 --memory=12000 --profile={{profile}}
