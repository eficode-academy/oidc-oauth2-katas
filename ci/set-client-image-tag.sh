#! /bin/bash

set -e

TAG=$1
IMAGE=praqma/oidc-oauth2-katas-client:$TAG

declare -a manifests=("kubernetes/client1.yaml" "kubernetes/client1-v2.yaml" "kubernetes/client1-v3.yaml" "kubernetes/client2.yaml" "kubernetes/hazard-service.yaml" "kubernetes/object-store-v2.yaml" "kubernetes/protected-api.yaml")

for m in "${manifests[@]}"; do
    sed -i -E "s#(^\s+-\s+image\: ).*#\1$IMAGE#" $m
done
