# OIDC in Browser-based Apps (SPAs)

## Learning Goals

- TBD

## Introduction

TBD

## Exercise

- Deploy ...

```console
export DOMAIN=user$USER_NUM.$TRAINING_NAME.eficode.academy
```

```console
kubectl create configmap spa-cdn \
    --from-literal=csp_connect_sources="https://login.$DOMAIN https://api.$DOMAIN" \
    --from-file=config.json
```

```console
kubectl apply -f kubernetes/spa-cdn.yaml
```

This deploys a content-delivery POD to Kubernetes, using a Kubernetes
service name of `spa`. This service has been linked with the domain
prefix `spa`, i.e. you can now access the application as the following
URL:

```console
export SPA_BASE_URL=https://spa.user$USER_NUM.$TRAINING_NAME.eficode.academy
```

Initially, the SPA will look like this:

> ![SPA login screen](images/spa-login.png)


```console
export CLIENT1_ID=client1
export CLIENT1_SECRET=<xxx>     # This is your client1 'credential'
export OIDC_ISSUER_URL=https://keycloak.user$USER_NUM.$TRAINING_NAME.eficode.academy/auth/realms/myrealm
```

```console
kubectl create secret generic client1 \
    --from-literal=client_id=$CLIENT1_ID \
    --from-literal=client_secret=$CLIENT1_SECRET
kubectl create configmap spa-login \
    --from-literal=oidc_issuer_url=$OIDC_ISSUER_URL  \
    --from-literal=spa_base_url=$SPA_BASE_URL
```

```console
kubectl apply -f kubernetes/spa-login.yaml
```




### Clean up

```console
kubectl delete -f kubernetes/spa-cdn.yaml
```
