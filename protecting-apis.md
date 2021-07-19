# Protecting APIs

## Learning Goals

- Protecting APIs with access tokens
- Understand the concept of token 'audience'



## Introduction

Here you will provide the bare minimum of information people need to solve the exercise.

## Subsections


## Exercise

### Overview

- In bullets, what are you going to solve as a student

### Step by step instructions

```console
export OIDC_ISSUER_URL=https://keycloak.user$USER_NUM.$TRAINING_NAME.eficode.academy/auth/realms/myrealm
```

Create a Kubernetes `ConfigMap` with this information:

```console
kubectl create configmap api \
    --from-literal=oidc_issuer_url=$OIDC_ISSUER_URL
```

and deploy the API:

```console
cd oidc-oauth2-katas/
kubectl apply -f kubernetes/protected-api.yaml
```

```console
export ACCESS_TOKEN=<xxx>
export API_EP=https://api.user$USER_NUM.$TRAINING_NAME.eficode.academy
curl -H "Authorization: Bearer $ACCESS_TOKEN" $API_EP/objects && echo ""
```

```console
export OBJID=`curl -s -H "Authorization: Bearer $ACCESS_TOKEN" $API_EP/objects | jq -r .[0]`
curl -H "Authorization: Bearer $ACCESS_TOKEN" $API_EP/object/$OBJID && echo ""
```

```console
curl -X POST -H "Authorization: Bearer $ACCESS_TOKEN" --data '{"title":"Test object 2"}' -H "Content-Type: application/json" $API_EP/object
curl -X POST -H "Authorization: Bearer $ACCESS_TOKEN" --data '{"title":"Test object 3"}' -H "Content-Type: application/json" $API_EP/object
curl -H "Authorization: Bearer $ACCESS_TOKEN" $API_EP/objects && echo ""
```

```console
kubectl logs -f -l app=api
```

```console
kubectl cp object-store/src/index.js `kubectl get pods -l app=api -o=jsonpath='{.items[0].metadata.name}'`:/app/oidc-oauth2-katas/object-store/src/
```

### Clean up
