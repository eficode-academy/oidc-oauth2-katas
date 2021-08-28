# Protecting against CSRF Attacks

## Learning Goals

- tbd

## Introduction

TBD

## Exercise

### Overview

- TBD

### Step by step instructions



```console
kubectl apply -f kubernetes/object-store-v2.yaml
```



First, set some variables that help us build URLs:

```console
export USER_NUM=<X>             # Use your assigned user number
export TRAINING_NAME=<xxx>      # Get this from your trainer
```

```console
export CLIENT1_ID=client1
export CLIENT1_SECRET=<xxx>     # This is your client1 'credential'
export OIDC_ISSUER_URL=https://keycloak.user$USER_NUM.$TRAINING_NAME.eficode.academy/auth/realms/myrealm
export OAUTH2_PROXY_EP=https://oauth2-proxy.user$USER_NUM.$TRAINING_NAME.eficode.academy
export OAUTH2_PROXY_UPSTREAM=http://object-store-v2:80
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


> ![Object store](images/object-store.png)


#### Setting Up the Hazard

In the following we set up a service that implements the CSRF
attack. We are deploying the service on Kubernetes alongside the
Object Store, however, this proximity is purely for practical reasons
and is not needed for the attack. The hazard could equally well run
anywhere else.


```
export LEGIT_CLIENT_URL=https://oauth2-proxy.user$USER_NUM.$TRAINING_NAME.eficode.academy
export HAZARD_URL=https://hazard.user$USER_NUM.$TRAINING_NAME.eficode.academy
```

```console
cat kubernetes/hazard-service.yaml | envsubst > hazard.yaml
kubectl apply -f hazard.yaml
```

Open two browser tabs, one with ordinary client at the URL stored in
`OAUTH2_PROXY_EP` and another with the hazard service at the URL
stored in `HAZARD_URL`.



Next, sign out from the object store by visiting the URL stored in
`OAUTH2_PROXY_EP` appended with `/oauth2/sign_out`. This deletes the
security association between the browser and the object store,
i.e. the hazard service cannot piggyback on this to execute the
attack.

After this revisit the link in the hazard service and following this
login again to the object store. You should now see, that no new
objects have been created.

#### Protecting Against CSRF




Before updating the client code, run the following command in a
separate console to see API log output:

```console
kubectl logs -f -l app=object-store-v2
```

Next, edit `object-store/src/index.js` and remove the `//` in front of
`allowScopes` **but keep the bogus `yyy` scope**. Since this is a scope we
do not have in out access token we should expect an error when trying
to access the API.








```
    <form action="/object" method="post">
      <input type="hidden" name="csrf-nonce" value="<%=csrf%>">
      <input type="text" placeholder="Enter content" name="content" size="50" required>
      <button type="submit">Create object</button>
    </form>
```

```
// This is a too simplistic approach, however, it illustrates how
// forms are modified to contains a CSRF nonce that proves the source
// of the POST operation recevied the form from a valid client.
// Real nonce's should be unguessable, i.e. be dynamically created.
const csrf_nonce = 'per-request-dynamic-hash';

// Serve front page
app.get('/', (req, res) => {
    console.log('Headers in request:', req.headers)
    const username = req.headers['x-forwarded-preferred-username']
    res.render('index', {client_title,
			 client_stylefile,
			 username,
			 csrf: csrf_nonce,
			 objects});
});

app.post('/object', (req, res) => {
    csrf = req.body['csrf-nonce'];
    if (csrf != csrf_nonce) {
	console.warn('Got CSRF nonce', csrf, 'expected', csrf_nonce);
    } else {
	const id = uuid.v4();
	objects[id] = req.body.content;
	console.log("Created object ", id, ", content '"+objects[id]+"'");
    }
    res.redirect('/');
});
```


Next, use `kubectl cp` to copy the code changes to the running API
POD:

```console
kubectl cp object-store-v2/src/views/index.ejs `kubectl get pods -l app=object-store-v2 -o=jsonpath='{.items[0].metadata.name}'`:/app/oidc-oauth2-katas/object-store-v2/src/views/
kubectl cp object-store-v2/src/client.js `kubectl get pods -l app=object-store-v2 -o=jsonpath='{.items[0].metadata.name}'`:/app/oidc-oauth2-katas/object-store-v2/src/
```

After this, you will see from the log output, that the object store service is restarted.




### Clean up

```console
helm delete oauth2-proxy
kubectl delete secret client1
kubectl delete -f kubernetes/object-store-v2.yaml
```
