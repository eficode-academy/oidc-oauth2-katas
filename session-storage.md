# Template headline

## Learning Goals

- How to add horisontal scalability by using an independent session storage

## Introduction


## Exercise

```console
export USER_NUM=<X>             # Use your assigned user number
export TRAINING_NAME=<xxx>      # Get this from your trainer
```

```console
export CLIENT1_ID=client1
export CLIENT1_SECRET=<xxx>     # This is your client1 'credential'
export CLIENT1_BASE_URL=https://client1.user$USER_NUM.$TRAINING_NAME.eficode.academy
export OIDC_ISSUER_URL=https://keycloak.user$USER_NUM.$TRAINING_NAME.eficode.academy/auth/realms/myrealm
```

### Sessions are not Shared Across PODs

Create a Kubernetes `ConfigMap` and `Secret` with this information:

```console
kubectl create secret generic client1 \
    --from-literal=client_id=$CLIENT1_ID \
    --from-literal=client_secret=$CLIENT1_SECRET
kubectl create configmap client1 \
    --from-literal=oidc_issuer_url=$OIDC_ISSUER_URL  \
    --from-literal=client_base_url=$CLIENT1_BASE_URL
```

and deploy the client:

```console
kubectl apply -f kubernetes/client1-v2.yaml
```

When the `client1` POD is `Running`, go to the URL stored in the
`CLIENT2_BASE_URL` environment variable and login to the client. Note,
that the POD name is shown in the header. Refresh the browser window a
few times - you should see the token details page as an indication of
the user being logged-in. Also, the POD name in the top does not
change since we only have a single POD replica running.

Next, scale the client deployment:

```console
kubectl scale --replicas 2 deployment client1
```

Wait until the new replica is running and then reload the page.  You
will see, that when you are directed to one of the new PODs, you are
no longer logged into the client. If you retry loading the page while
manually adding `/user` to the end of the URL, you will be considered
logged-in when you are directed to the original POD.

This is because the `v2` client is storing the session information in
memory locally within the POD.

### Login State is not Shared Across PODs

```console
kubectl scale --replicas 0 deployment client1
kubectl scale --replicas 3 deployment client1
```



```console
kubectl delete -f kubernetes/client1-v2.yaml
```

```console
kubectl delete configmap client1
kubectl create configmap client1 \
    --from-literal=oidc_issuer_url=$OIDC_ISSUER_URL  \
    --from-literal=client_base_url=$CLIENT1_BASE_URL \
    --from-literal=redis_url=redis://session-store
```

```console
kubectl apply -f kubernetes/client1-v3.yaml
```

```console
kubectl scale --replicas 3 deployment client1
```


```console
kubectl exec -it `kubectl get pods -l app=session-store -o=jsonpath='{.items[0].metadata.name}'` -- redis-cli
```

```console
127.0.0.1:6379> keys *
```

```console
127.0.0.1:6379> keys *
(empty array)
```

### Clean up
