# Confidential Client with Authorization Code Flow

## Learning Goals

- Detailed look at the authorization code flow
- Understanding the Context of a login-session
- Investigate identity provider session cookies
- Single-sign-on (SSO) using a second client

## Introduction

This exercise extend on
[part-1](confidential-client-auth-code-flow.md) and goes into more
details on the authorization code flows and the security sessions that
are involved.

## Exercise

### How the Client Implemented the Authorization Code Flow

OIDC was designed such that complexity lies mainly with the identity
provider/authorization server and clients are kept simple.

Now is a good time to investigate the [client code](client-nodejs/src/client.js).

The application flow is:

1. Initially [index.html](client-nodejs/src/views/index.html) is
retrieved from the `/` path (look for a `// Serve login page`
comment).

2. The login page have an HTML form which `POST` to the client
`/login` endpoint (look for a `// First step in an authorization code
flow login` comment).

3. The `/login` endpoint builds a URL for the identity provider
authorization endpoint and redirects the browser there. A parameter to
the identity provider is the clients `redirect_uri`, i.e. the client
callback where the identity provider redirects when login is complete.

4. After Identity provider login we are redirected to the `/callback`
client endpoint (look for a `// Second step, we get a callback from
the IdP after a successful login.` comment)

5. In the client `/callback` endpoint, the client retrieves the `code`
which the identity provider included and subsequently the client use
the identity provider token endpoint to exchange the `code` for tokens
(look for a `// Exchange code for tokens using the token endpoint`
comment).

6. If the code-to-token exchange is successful, the client stores
these as global variables and redirect to the client base URL `/`. At
the base URL, if the client have tokens stored in global variables, it
redirects to the `protected` endpoint and shows the content of the
tokens. This is the page we saw above titled `Token Received by
Client`.

7. This completes an OIDC login using the authorization code flow.

### Login Observed from Client Logs

We can match the above process with the logs from the client. To
inspect the client logs, use the following command:

```console
kubectl logs -f --tail=-1 -l app=client1 -c client |less
```

Hint: To search in `less` use `\`, to go to the start of the logs use
`g` and the end use `G`. To exit less use `q`.

The login redirection to the identity provider can be seen from the
line staring with:

```
Redirecting login to identity provider ...
```

In the redirection, note how the authorization code flow is initiated
with a parameter `response_type=code` and our client redirection URL
are included as parameter `redirect_uri`. Note that e.g. URLs are
encoded such that e.g. `:` becomes `%3A`. This is ordinary HTTP URL
encoding.

When the login is completed at the identity provider, we are
redirected to the client. Locate the line starting with:

```
GET /callback ...
```

In this callback we see a `state` parameter that matches the one we
specified in the redirection to the identity provider above and we
also get a new `code` parameter.

The code can be exchanged for tokens, and we see the content of the
exchange from the lines starting with:

```
POST to https://keycloak.user1 ...
 using options ...
 using data code= ...
```

We see, that the code-to-token exchange is authorized with our client
credentials in the `Authorization` header. If you decode the
credentials data from the `Authorization` header you will find the
client credentials we configured previously). In the payload of the
POST we see the code which we now are exchanging for tokens.

Subsequent lines show the tokens received from the exchange in the
JSON object following the line starting with `Token response`.

### Identity Provider Session Cookies

To demonstrate, that the user login sessions is independent of the
client and only exists between your browser and the identity provider,
we redeploy the client with the following:

```console
kubectl delete -f kubernetes/client1.yaml
kubectl apply -f kubernetes/client1.yaml
```

Reload the client page again when the POD becomes `Running`. The
client is not aware of the login session that exists between the
browser and identity provider, i.e. you will have to select `Login`
again. When you click `Login` you will notice that you are immediately
logged in.

> Note: If you are prompted for login information it might be because the login session has expired. KeyCloak use a session timeout of 30 minutes. If this happens, redeploy the client once more and re-login using the fresh login session.

To see the cookies, which stores this session between browser and
identity provider, open the identity provider authorization URL (the
one we stored in the `OIDC_AUTH_URL` environment variable) in a
browser tab - ignoring any errors. Right-click and select `Inspect`.

> Note: This works in Chrome and Firefox. The procedure may be different in other browsers.

In the information window that opens, select `Applications` and
`Cookies` as shown below. KeyCloak cookies are shown in the example
here. Other identity providers will use different cookie names.

> ![KeyCloak session cookies](images/keycloak-session-cookies-anno.png)

Try deleting the cookies by right-clicking over the cookie-domain in
the left-hand side (under `3` in the image) and select
`Clear`.

First, refresh the client in the browser window - you will see, that
deleting the KeyCloak cookies had no effect on the client.

Second, redeploy the client as above and retry the login. This time
you will be prompted for login information.

<details>
<summary>:bulb:What about 'consent' - I was not asked about it this time?</summary>

You may notice, that you where not asked about consent once more. Identity providers typically only asks this initially and then stores the consent for each user+client. You can find this in KeyCloak under `Users` and `Consent`. Consent is an 'agreement' between you/browser and the identity provider. The redeployed client used the existing consent agreement for `client1`.
</details>

<details>
<summary>:bulb:The example client does not use cookies. What are the security implications of this?</summary>

The example client use global variables to store tokens and does not set any browser cookies with e.g. session IDs. This means that there is no browser-to-client authentication and authorization. Anyone accessing the client can see the tokens!
</details>

### Single Sign On (SSO)

Since the user login sessions exists between browser and identity
provider and not between client(s) and identity provider, the setup
supports single-sign-on. To demonstrate this, we deploy a second
client similar to `client1`.

Store `client2` information in environment variables (using the
secret/credential for client2, not the one from client1):

```console
export CLIENT2_ID=client2
export CLIENT2_SECRET=<xxx>     # This is your client2 'credential'
export CLIENT2_BASE_URL=https://client2.user$USER_NUM.$TRAINING_NAME.eficode.academy
```

Create a Kubernetes `ConfigMap` and `Secret` with this information:

```console
kubectl create secret generic client2 \
    --from-literal=client_id=$CLIENT2_ID \
    --from-literal=client_secret=$CLIENT2_SECRET
kubectl create configmap client2 \
    --from-literal=oidc_auth_url=$OIDC_AUTH_URL  \
    --from-literal=oidc_token_url=$OIDC_TOKEN_URL \
    --from-literal=client_base_url=$CLIENT2_BASE_URL
```

and deploy the client:

```console
kubectl apply -f kubernetes/client2.yaml
```

When the `client2` POD is `Running`, go to the URL stored in the
`CLIENT2_BASE_URL` environment variable.  When clicking login in
`client2`, you will be asked for consent because this is a new client
requesting access to the user profile, but you will not be requested
to provide user login information because the already existed a
security session between user/browser and KeyCloak and this is handled
through the cookies as we saw before.

> ![Client2 displays tokens](images/client2-token-screen.png)

Later we will see, that this opens up for a serious type of attack,
which we will cover in exercise [Protecting against CSRF
Attacks](csrf-attacks.md)

### Clean up

```console
kubectl delete -f kubernetes/client1.yaml
kubectl delete -f kubernetes/client2.yaml
kubectl delete secret client1
kubectl delete configmap client1
kubectl delete secret client2
kubectl delete configmap client2
```
