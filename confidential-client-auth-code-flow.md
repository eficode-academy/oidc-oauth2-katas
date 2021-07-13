# Confidential Client with Authorization Code Flow

## Learning Goals

- Configure a confidential client to work with an OIDC identity provider
- Hands-on with the requests and responses of the authorization code flow
- Decoding ID-tokens/JWTs
- What is the Context of a login-session
- Investigate identity provider session cookies
- Single-sign-on (SSO) using a second client

## Introduction

This exercise demonstrate OIDC login using a server-based client also
known as a 'confidential client'. Login will be implemented using the
'authorization code flow', which is the recommended approach for most
situations.

## Prerequisites

This exercise require an identity provider configured with one or more
test users and a client configuration that allow our client to login
users through the identity provider. See e.g. [Setting up
KeyCloak](setting-up-keycloak.md) for how to configure KeyCloak for
this exercise.

Specifically you will need:

- A client ID
- A client secret
- An authorization URL
- A token URL

The two first you should know from your identity provider
configuration (e.g. from setting up KeyCloak as described above).  The
two latter will be obtained from our authorization server using 'OIDC
Discovery' which is a mechanism to allow OIDC Authorization servers to
publish information on well-known URLs.

Assuming your KeyCloak instance is located at:

```
https://keycloak.user<X>.<training-name>.eficode.academy
```

then you can fetch the OIDC configuration with (assuming your realm was named `myrealm`):

```console
export USER_NUM=<X>             # Use your assigned user number
export TRAINING_NAME=<xxx>      # Get this from your trainer
curl -s https://keycloak.user$USER_NUM.$TRAINING_NAME.eficode.academy/auth/realms/myrealm/.well-known/openid-configuration | jq .
```

Specifically, the authorization and token URLs can be found with:

```console
curl -s https://keycloak.user$USER_NUM.$TRAINING_NAME.eficode.academy/auth/realms/myrealm/.well-known/openid-configuration | jq .authorization_endpoint
curl -s https://keycloak.user$USER_NUM.$TRAINING_NAME.eficode.academy/auth/realms/myrealm/.well-known/openid-configuration | jq .token_endpoint
```

For convenience you might want to export the settings as environment variables:

```console
export CLIENT1_ID=client1
export CLIENT1_SECRET=<xxx>     # This is your client1 'credential'
export OIDC_AUTH_URL=`curl -s https://keycloak.user$USER_NUM.$TRAINING_NAME.eficode.academy/auth/realms/myrealm/.well-known/openid-configuration | jq -r .authorization_endpoint`
export OIDC_TOKEN_URL=`curl -s https://keycloak.user$USER_NUM.$TRAINING_NAME.eficode.academy/auth/realms/myrealm/.well-known/openid-configuration | jq -r .token_endpoint`
```

## Exercise

With the required settings stored as environment variables as
described above, you are ready to deploy the client. To see the
configured settings use:

```console
env | egrep 'OIDC|CLIENT[12]_'
```

We will deploy the server-based client using Kubernetes and the client will be accessible at the URL below.

```console
export CLIENT1_BASE_URL=https://client1.user$USER_NUM.$TRAINING_NAME.eficode.academy
```

The client can also run locally in which case the URL should be
changed to e.g. `http://localhost:5000`. This is however, not part of
this exercise.

For the Kubernetes deployment, we make the above configuration
available as a `ConfigMap` and `Secret`. Use the commands below to
create these:

```console
kubectl create secret generic client1 \
    --from-literal=client_id=$CLIENT1_ID \
    --from-literal=client_secret=$CLIENT1_SECRET
kubectl create configmap client1 \
    --from-literal=oidc_auth_url=$OIDC_AUTH_URL  \
    --from-literal=oidc_token_url=$OIDC_TOKEN_URL \
    --from-literal=client_base_url=$CLIENT1_BASE_URL
```

With the configuration in place, we are ready to deploy the client. Use the following to deploy the client:

```console
cd oidc-oauth2-katas
kubectl apply -f kubernetes/client1.yaml
```

```console
kubectl logs -f -l app=client1 -c client
```

When the client POD is `Running`, visit the client at the URL you
stored in `$CLIENT1_BASE_URL`. You should see something like:

> ![Client1 login screen](images/client1-login-screen.png)

This client explicitly shows the scope it will request from the
identity provider. Many clients do not show this to the end-user. The
default scope `openid profile` means 'do an OIDC login and give us
access to user profile'.

Click login and you will be redirected to the identity provider where
you can login. If you followed the [Setting up
KeyCloak](setting-up-keycloak.md) guide, you will be presented with a
consent screen:

> ![Grant access to client1 screen](images/keycloak-grant-access-to-client1.png)

This is because we configured KeyCloak to ask for consent. Not all
client/identity-provider setups include this, i.e. they will
immediately issue tokens.

When login are completed, you are redirected to the client, and the
client will display the content of the ID token it received (i.e. the
'claims' which the identity provider asserts are true):

> ![Client1 displays tokens](images/client1-token-screen.png)

The client shows both the raw ID token and the decoded claims. We can
decode the JWT token ourself using the command line. This is often
useful during debugging sessions.  To decode the token manually, copy
the raw token and store it in an environment variable:

```console
export IDTOKEN=<raw token data>
echo $IDTOKEN | cut -d. -f2 | base64 -d | jq .
```

> If you get an `base64: invalid input` warning from this command then its most likely because the base64 encoded data is not a multiple of 4 characters. I.e. the output if `cut` needs to be padded with a number of `=` characters. This warning is however, safe to ignore.

### How the Client Implemented the Authorization Code Flow

OIDC was designed such that complexity lies mainly with the identity
provider/authorization server and clients are kept simple.

Now is a good time to investigate the [client code](client-nodejs/src/client.js).

The application flow is:

1. Initially [index.html](client-nodejs/src/views/index.html) is
shown. This page have a form which posts to the clients `/login`
endpoint.

2. The `/login` endpoint builds a URL for the identity provider
authorization endpoint and redirects the browser there. A parameter to
the identity provider is the clients `redirect_uri`, i.e. the client
callback which the identity provider calls when login is complete.

3. In the client callback endpoint `/callback`, the client retrieves
the `code` which the identity provider included and subsequently the
client use the identity provider token endpoint to exchange the `code`
for tokens.

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
browser and identity provider, i.e. you will have to clock `Login`
again. When you click `Login` you will notice that you are immediately
logged in.

> Note: If you are prompted for login information it might be because the login session has expired. KeyCloak use a default timeout of 30 minutes. If this happens, redeploy the client once more and re-login using the fresh login session.

To see the cookies, which stores this session between browser and
identity provider, open the identity provider authorization URL (the
one we stored in the `OIDC_AUTH_URL` environment variable) in a
browser tab - ignoring any errors. Right-click and select `Inspect`.

> Note: This works in Chrome and Firefox. The procedure may be different in other browsers.

In the information window that opens, select `Applications` and
`Cookies` as shown below. KeyCloak cookies are shown in the example
here. Other identity provider may use different cookie names.

> ![KeyCloak session cookies](images/keycloak-session-cookies-anno.png)

Try deleting the cookies by right-clicking over the cookie-domain in
the left-hand side (under `3` in the image) and select
`Clear`. Redeploy the client as above and retry the login. This time
you will be prompted for login information.

<details>
<summary>:bulb:What about 'consent'?</summary>

You may notice, that you where not asked about consent once more. Identity providers typically only asks this initially and then stores the consent. You can find this in KeyCloak under `Users` and `Consent`.
</details>

### Single Sign On (SSO)

Since the user login sessions exists between browser and identity
provider, OIDC supports single-sign-on. To demonstrate this, we deploy
a second client similar to `client1`.

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
to provide user login information.

> ![Client2 displays tokens](images/client2-token-screen.png)

### Clean up

TBD.