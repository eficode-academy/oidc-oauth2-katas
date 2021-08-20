# Using Authorizing Proxies

## Learning Goals

- provide a list of goals to learn here

## Introduction

Here you will provide the bare minimum of information people need to solve the exercise.

## Exercise

First, set some variables that help us build URLs:

```console
export USER_NUM=<X>             # Use your assigned user number
export TRAINING_NAME=<xxx>      # Get this from your trainer
```

For convenience, set the following variables:

```console
export CLIENT1_ID=client1
export CLIENT1_SECRET=<xxx>     # This is your client1 'credential'
export OIDC_ISSUER_URL=https://keycloak.user$USER_NUM.$TRAINING_NAME.eficode.academy/auth/realms/myrealm
export OAUTH2_PROXY_EP= xxx
```

```
kubectl create secret generic client1 \
    --from-literal=client-id=$CLIENT1_ID \
    --from-literal=client-secret=$CLIENT1_SECRET \
    --from-literal=cookie-secret=abcdefgh12345678
```

```console
cat kubernetes/oauth2-proxy-values.yaml | envsubst > my-values.yaml
cat my-values.yaml
```

```console
helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests
helm install oauth2-proxy oauth2-proxy/oauth2-proxy --values my-values.yaml
```


### Clean up

