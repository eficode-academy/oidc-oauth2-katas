# Session Storage

## Learning Goals

- How to add horisontal scalability by using an independent session storage
- See the login and logged-in experience with and without a shared session storage
- Inspect data in session storage and correlate with browser cookies

## Introduction

With a confidential client we have the authentication and
authorization information (the tokens) stored in the server-side
client and the association to the user browser is through a session
cookie that links to the session state with the token.

This exercise will demonstrate that such an architecture require a
separate session store using horozontal scaling of the client, e.g. a
typical usecase with Kubernetes Deployments.

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
export CLIENT1_BASE_URL=https://client1.user$USER_NUM.$TRAINING_NAME.eficode.academy
export OIDC_ISSUER_URL=https://keycloak.user$USER_NUM.$TRAINING_NAME.eficode.academy/auth/realms/myrealm
```

### Sessions are not Shared Across PODs

Create a Kubernetes `ConfigMap` and `Secret` for client configuration:

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
cd oidc-oauth2-katas/
kubectl apply -f kubernetes/client1-v2.yaml
```

When the `client1` POD is `Running`, go to the URL stored in the
`CLIENT1_BASE_URL` environment variable and login to the client. Note,
that the POD name and access time is shown in the header. Refresh the
browser window a few times - you should see the token details page as
an indication of the user being logged-in. Also, only the timestamp
shown in the header changes since we only have a single POD replica
running.

Next, scale the client deployment:

```console
kubectl scale --replicas 4 deployment client1
```

<details>
<summary>:bulb: Why so many replicas?</summary>
Your browser may keep TCP connections open for a short while to
optimize subsequent requests and this means that reloads could reuse
the existing connection, i.e. reloads only go to a new POD when the
browser recreates the TCP connection (typically after some
minutes). The training infrastructure is deployed in a
multi-availability zone setup and with more than 2 replicas theres a
good probability that we get round-robin load balancing inside
Kubernetes.
</details>

Wait until the new replicas are running and then reload the page.  You
will see, that when you are directed to one of the new PODs, you are
no longer logged into the client. If you retry loading the page while
manually adding `/user` to the end of the URL, you will be considered
logged-in only when you are directed to the original POD.

This is because the `v2` client is storing the session information in
memory locally within the POD.

### Login State is not Shared Across PODs

Next we will show, that its not only the login session information
that is stored locally in each client POD.

First, deploy the client (to ensure that no state exists from previous
login):

```console
kubectl scale --replicas 0 deployment client1
kubectl scale --replicas 4 deployment client1
```

Finally, try logging in. You should experience that it is not possible
and that you get an error:

```
did not find expected authorization request details in session, req.session ... is undefined
```

<details>
<summary>:bulb: What could be the problem (hint: The client is using the 'authorization code flow')?</summary>
The authorization code flow provides a `state` and `nonce` parameter
to the authorization process and validates that these are present in
the identity provider callback. These parameters are stored in the
session during login.
</details>

### Adding Shared Session Storage

A common architectural pattern used with horisontally scaled
applications is a shared session storage. All application replicas
will write and read session information from this shared session
storage.  We will use [Redis](https://redis.io/) for session storage
but several other solutions exists.

First un-deploy the client with POD-internal session storage:

```console
kubectl delete -f kubernetes/client1-v2.yaml
```

Next, recreate the `client1` Kubernetes Configmap with an additional
value - we will deploy Redis using a Kubernetes service named
`session-store` and we add this Redis URL to the configmap:

```console
kubectl delete configmap client1
kubectl create configmap client1 \
    --from-literal=oidc_issuer_url=$OIDC_ISSUER_URL  \
    --from-literal=client_base_url=$CLIENT1_BASE_URL \
    --from-literal=redis_url=redis://session-store
```

Next, deploy v3 of the client - this time with an additional Redis
deployment. Also, we scale it to four replicas:

```console
kubectl apply -f kubernetes/client1-v3.yaml
kubectl scale --replicas 4 deployment client1
```

Before logging in, open a Redis CLI with the following command:

```console
kubectl exec -it `kubectl get pods -l app=session-store -o=jsonpath='{.items[0].metadata.name}'` -- redis-cli
```

and run a `keys *` command. You should expect to see `(empty array)`
because the session storage is currently empty.

```console
127.0.0.1:6379> keys *
(empty array)
```

Finally, do a login followed by a few refreshes - you will see, that
now the client works well irrespective of which POD handles our
traffic.

If you re-run the `keys *` command in the Redis CLI, you will see a
since key and you will be able to match the key value to a cookie in
you browser. You may also try reading the session data from the Redis
CLI using a `get <key>` command (where `<key>` is the key you find
from `keys *`).

<details>
<summary>:bulb: The session storage is currently deployed without any persistence, i.e. no data is save to persistent storage. What will happen if the Redis POD is restarted?</summary>

If the session storage is restarted, a lookup for an existing session
will fail, and the application should handle this as a normal 'session
not valid' situation and redirect to the login endpoint.

You may try it out by deleting the session-store POD!

</details>

<details>
<summary>:bulb: The session storage 'keys' command is also available to the clients. Is that a problem?</summary>

For security reasons, session data lookup should be one-way, i.e. the
session-ID should be sufficiently difficult to guess/predict, such
that the client cannot access all the session data (which includes all
users' tokens).

In the example provided, there is also no authentication between the
client and the session storage. A production solution should have
this.

</details>

### Clean up

```console
kubectl delete -f kubernetes/client1-v3.yaml
kubectl delete secret client1
kubectl delete configmap client1
```
