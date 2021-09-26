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
kubectl create configmap cdn \
    --from-literal=csp_connect_sources="https://login.$DOMAIN https://api.$DOMAIN"
```

```console
kubectl apply -f kubernetes/spa-cdn.yaml
```

This deploys a content-delivery POD to Kubernetes, using a Kubernetes
service name of `spa`. This service has been linked with the domain
prefix `spa`, i.e. you can now access the application as the following
URL:

```console
export SPA_URL=https://spa.user$USER_NUM.$TRAINING_NAME.eficode.academy
```

Initially, the SPA will look like this:

> ![SPA login screen](images/spa-login.png)






### Clean up

```console
kubectl delete -f kubernetes/spa-cdn.yaml
```
