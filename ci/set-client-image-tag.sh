#! /bin/bash

set -e

TAG=$1

if [ -z "$TAG" ]; then
    SHA=`git rev-parse --short HEAD`
    TAG="sha-$SHA"
    echo "No image tag specified, using HEAD: $TAG"
fi

IMAGE=praqma/oidc-oauth2-katas-client

for m in "kubernetes/client1.yaml" "kubernetes/client1-v2.yaml" "kubernetes/client1-v3.yaml" "kubernetes/client2.yaml" "kubernetes/hazard-service.yaml" "kubernetes/object-store-v2.yaml" "kubernetes/protected-api.yaml" "kubernetes/spa-cdn.yaml" "kubernetes/spa-login.yaml"; do
    sed -i -E "s#(^\s+-\s+image\:\s+$IMAGE\:).*#\1$TAG#" $m
done
