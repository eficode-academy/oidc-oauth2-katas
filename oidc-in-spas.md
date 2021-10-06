# OIDC in Browser-based Apps (SPAs)

This exercise will demonstrate how to implement OIDC in browser-based
applications, aka. single-page-applications (SPAs).  OIDC will be
implemented using authorization code flow with the
backend-for-frontend (BFF) pattern. This means, that for improved
security, the OIDc functionality is handled server-side in close
collaboration with the SPA.

The architecture is illustrated below. The API (white box in lower
right corner) the SPA accesses is the `object-store` we used in
exercise [Protecting Resources and APIs](protecting-apis.md)

> ![SPA components and architecture](images/spa-architecture.png)

## Learning Goals

- OIDC in SPAs
- Backend-for-frontend pattern

## Exercise

First, set some variables that help us build URLs:

```console
export DOMAIN=user$USER_NUM.$TRAINING_NAME.eficode.academy
export SPA_BASE_URL=https://spa.$DOMAIN
```

Next, create a new OIDC client `spa` for this exercise - use the same
procedure as in previous exercises [Setting up
KeyCloak](setting-up-keycloak.md), **with the exception, that you
should set `Access Token Lifespan` to 1 minute**. This is a low
lifespan, but we do this to demonstrate token refresh without too
much waiting time.

### Deploy SPA

First we deploy a simple server that merely servers the static files
of the SPA. We call this `spa-cdn`. This server will send a
[Content-Security-Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy)
(CSP) HTTP header for added security. We configure the CSP policy such
that the SPA is only allowed make connections to its own base
URL. This provides strong protection against cross-site scripting
attacks.

Configure and deploy `spa-cdn` with:

```console
kubectl create configmap spa-cdn \
    --from-literal=csp_connect_sources="$SPA_BASE_URL"
kubectl apply -f kubernetes/spa-cdn.yaml
```

You can now access the SPA at the URL you stored in the `SPA_BASE_URL`
environment variable above.:

Initially the SPA will look like shown below, but it will not be fully
functional since we are still missing some components.

> ![SPA login screen](images/spa-login.png)

### Deploy BFF

Next we will deploy the backend-for-frontend (BFF), which we call
`login`. First create environment variables for our identity provider:

```console
export SPA_CLIENT_ID=spa
export SPA_CLIENT_SECRET=<xxx>
export OIDC_ISSUER_URL=https://keycloak.$DOMAIN/auth/realms/myrealm
```

and create a `Secret` and `ConfigMap` with this information. Note that
we use the SPA base URL as the redirection URL, i.e. where we return
after having completed login at the identity provider:

```console
kubectl create secret generic spa-client \
    --from-literal=client_id=$SPA_CLIENT_ID \
    --from-literal=client_secret=$SPA_CLIENT_SECRET
kubectl create configmap spa-login \
    --from-literal=oidc_issuer_url=$OIDC_ISSUER_URL  \
    --from-literal=redirect_url=$SPA_BASE_URL
```

Finally, deploy the `login` component:

```console
kubectl apply -f kubernetes/spa-login.yaml
```

### Deploy API

We will use the 'object store' from exercise [Protecting Resources and
APIs](protecting-apis.md) as an example of a protected resource with
an API that use an access token to authorizing access. The
object-store allow any access token as long at it comes from a trustet
provider.

Create a `ConfigMap` with the OIDC issuer from which the object-store
will trust access tokens:

```console
kubectl create configmap api \
    --from-literal=oidc_issuer_url=$OIDC_ISSUER_URL
```

and deploy the API:

```console
kubectl apply -f kubernetes/protected-api.yaml
```

### Deploy API Gateway

The SPA cannot access the API yet, since it needs a component to
exchange the session cookie for an access token. The API gateway
component does that.

Deploy the API gateway with:

```console
kubectl apply -f kubernetes/spa-api-gw.yaml
```

All components of the SPA are now deployed.

## Login Through Backend-for-Frontend

To monitor an OIDC login with the SPA, monitor the BFF logs with the following command:

```console
kubectl logs -f --tail=-1 -l app=spa-login -c client
```

Second, right-click in your browser and select 'Inspect' in the menu
and second 'Console' to watch debug output from the SPA:

> ![SPA Console](images/spa-console-anno.png)

The four 'login-related' buttons are bound to BFF operations as follows:

- `Login` - BFF path `/login` - the BFF will return a URL which the SPA should redirect to for OIDC login
- `Logout` - BFF path `/logout` - the BFF will return a URL which the SPA should redirect to for OIDC logout
- `Get User Info` - BFF path `/userinfo` - the BFF will return ID token claims
- `Refresh Tokens` - BFF path `/refresh` - the BFF will initiate token refresh from the OIDC provider

Finally, the SPA will *on all pageloads* call the BFF path
`/pageload`. This is necessary to forward the authorization code flow
`code` back to the BFF such that it can complete an authorization code
flow login.

Inspect the SPA Javascript
[app.js](spa/spa-app-vanilla-js/dist/js/app.js) and observe e.g. how
the `doLogin` button is bound to the `doBFFLogin` Javascript function
on page load and also how the SPA calls `doBFFPageLoad()` with the
full page URL:

```
window.addEventListener('load', () => {
    ...
    $('#doLogin').click(doBFFLogin);
    ...
    doBFFPageLoad(location.href);
});
```

<details>
<summary>:bulb: The SPA links HTML buttons with code explicitly in Javascript code instead of embedding it in the HTML. Why could that be?</summary>
This is because the Content-Security-Policy did not allow in-line Javascript in HTML code. This is to protect against cross-site injection attacks.
</details>

When clicking the `Login` button, the SPA calls the `doBFFLogin()`
function and makes a request to the BFF. The BFF return a JSON
structure with an `authRedirUrl` where the SPA should redirect for the
OIDC login. Further details of the BFF communication can be found in
the [BFF README](spa/bff/README.md).

```
const doBFFLogin = async () => {
    data = await doBFFRequest('POST', '/start', null);
    location.href = data['authRedirUrl']
}
```


### Clean up

```console
kubectl delete -f kubernetes/spa-cdn.yaml
kubectl delete -f kubernetes/spa-login.yaml
kubectl delete -f kubernetes/spa-api-gw.yaml
kubectl delete -f kubernetes/protected-api.yaml
kubectl delete cm spa-cdn spa-login api
kubectl delete secret spa-client
```
