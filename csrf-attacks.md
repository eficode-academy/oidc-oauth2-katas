# Protecting against CSRF Attacks

## Learning Goals

- Protecting an application against the CSRF attack
- See the CSRF attack in-action to understand the nature of it

## Introduction

In this exercise we will deploy an object store protected by [OAuth2
proxy](https://github.com/oauth2-proxy/oauth2-proxy). However, even
though we apply a production-grade solution such as OAuth2-proxy, we
will demonstrate how easy it is to bypass and store objects in the
object store if we can trick the user to click an rogue link.

## Exercise

First, we deploy the object store. This creates a Kubernetes
deployment and a Kubernetes `ClusterIP` service, i.e. it is only
accessible inside the Kubernetes cluster:

```console
kubectl apply -f kubernetes/object-store-v2.yaml
```

Next, set some environment variables with your personal values:

```console
export USER_NUM=<X>             # Use your assigned user number
export TRAINING_NAME=<xxx>      # Get this from your trainer
export CLIENT1_ID=client1       # Change this if you didn't use this client name
export CLIENT1_SECRET=<xxx>     # This is your client1 'credential'
```

From the values above, define the following environment variables:

```console
export OIDC_ISSUER_URL=https://keycloak.user$USER_NUM.$TRAINING_NAME.eficode.academy/auth/realms/myrealm
export OAUTH2_PROXY_EP=https://oauth2-proxy.user$USER_NUM.$TRAINING_NAME.eficode.academy
export OAUTH2_PROXY_UPSTREAM=http://object-store-v2:80
```

Since OAuth2-proxy will interact with the identity-provider to
authenticate users, we will have to create a secret with the client ID
and secret. Also, OAuth2-proxy will manage a session through signed
cookies, i.e. it requires a secret for cookie signatures. Thus, we
create a secret for OAuth2-proxy with:

```
kubectl create secret generic client1 \
    --from-literal=client-id=$CLIENT1_ID \
    --from-literal=client-secret=$CLIENT1_SECRET \
    --from-literal=cookie-secret=abcdefgh12345678
```

Next we configure OAuth2-proxy Helm chart values with URLs from the
environment variables above:

```console
cat kubernetes/oauth2-proxy-values.yaml | envsubst > my-values.yaml
cat my-values.yaml
```

Inspect the generated Helm chart values.

Knowing that OAuth2-proxy implements the OIDC authorization code flow,
the `oidc_issuer_url` and `redirect_url` parameters should look
familiar.

The `upstreams` parameter is the service behind the proxy, i.e. this is
our object store Kubernetes service.

Finally, the `email_domains` parameter is the authorization policy
that OAuth2-proxy applies, i.e. any user with a verified email from
the given domain are authorized to access the protected service.

Next, install OAuth2-proxy with Helm:

```console
helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests
helm install oauth2-proxy oauth2-proxy/oauth2-proxy --values my-values.yaml
```

When the OAuth2-proxy and object store PODs are `Running`, access the
URL we stored in the `OAUTH2_PROXY_EP` environment variable
above. First you will see the OAuth2-login page, which looks like
this:

> ![OAuth2-proxy login page](images/oauth2-proxy-login.png)

Click `Sign in with...` and you are redirected to KeyCloak.

<details>
<summary>Initially, you get an 'Illegal redirection URL error' - what could be wrong?</summary>
We are reusing the `client1` configuration and the `client1` configuration in KeyCloak only allow validating users and redirecting back to a URL starting with `client1`. Go to the `client1` settings in KeyCloak and change the URL to start with the `oauth2-proxy` we now are using.
</details>

Finally you are logged in, and you can access the protected object store:

> ![Object store](images/object-store.png)

The object store show existing objects in the store and the input
allow you to create additional objects.

#### Setting Up the Hazard

In the following we set up a service that implements the CSRF
attack. We are deploying the service on Kubernetes alongside the
Object Store, however, this proximity is purely for practical reasons
and is not needed for the attack. The hazard could equally well run
anywhere else.

Create the following environment variables, the first is the target
URL of the attack, i.e. our object store. The second URL is where we
can access the link that trigger the CSRF attack.

```console
export LEGIT_CLIENT_URL=$OAUTH2_PROXY_EP
export HAZARD_URL=https://hazard.user$USER_NUM.$TRAINING_NAME.eficode.academy
```

Finally, deploy the hazard service:

```console
cat kubernetes/hazard-service.yaml | envsubst > hazard.yaml
kubectl apply -f hazard.yaml
```

Open a second browser tab, keep one with ordinary client at the URL
stored in `OAUTH2_PROXY_EP` and another with the hazard service at the
URL stored in `HAZARD_URL`. The hazard service looks like this:

> ![The hazard service](images/hazard.png)

Click the link on the hazard service and notice that nothing indicates
that you just created a new object in the object store. Go to the
other tab with the object store and refresh the page to see the 'Rouge
content' created by the CSRF.

#### Signing Out Protects Against CSRF

Next, sign out from the object store by clicking the `LOGOUT`
button. This deletes the security association between the browser and
the object store, i.e. the hazard service cannot piggyback on this to
execute the attack.

After this revisit the link in the hazard service - you should see no
difference in the response of the hazard service.

Finally, login to the object store again. You should now see, that no
new objects have been created.

#### Protecting the Object Store Against CSRF

In the following we will protect the object store against CSRF using a
pattern known as 'double submit cookie pattern'.

Before updating the client code, run the following command in a
separate console to see API log output:

```console
kubectl logs -f -l app=object-store-v2
```




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
// of the POST operation received the form from a valid client.
// Real nonce's should be un-guessable, i.e. be dynamically created.
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
