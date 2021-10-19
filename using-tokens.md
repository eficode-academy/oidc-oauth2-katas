# Using Tokens

## Learning Goals

- Using tokens from the command-line to access protected resources
- Observe difference between 'userinfo' from identity provider and ID-token
- Introspecting tokens through the Identity provider
- Refreshing tokens
- Revalidate user/browser login session
- Client-side logout using tokens

## Introduction

Exercise [Confidential Client with Authorization Code
Flow](confidential-client-auth-code-flow.md) demonstrated how to
obtain tokens using the authorization code flow.

With the access token, the client can access protected resources,
however, the tokens can also easily be used 'manually' from the
command-line. This exercise will demonstrate how to use tokens from
the terminal with `curl`.

## Exercise

### Deploy Client

First, set some variables that help us build URLs:

```console
export USER_NUM=<X>             # Use your assigned user number
export TRAINING_NAME=<xxx>      # Get this from your trainer
export CLIENT1_ID=client1
export CLIENT1_SECRET=<xxx>     # This is your client1 'credential'
```

For convenience, set the following variables:

```console
export CLIENT1_BASE_URL=https://client1.student$USER_NUM.$TRAINING_NAME.eficode.academy
export OIDC_ISSUER_URL=https://keycloak.student$USER_NUM.$TRAINING_NAME.eficode.academy/auth/realms/myrealm
```

Next, create a Kubernetes `ConfigMap` and `Secret` for client configuration:

```console
kubectl create secret generic client1 \
    --from-literal=client_id=$CLIENT1_ID \
    --from-literal=client_secret=$CLIENT1_SECRET
kubectl create configmap client1 \
    --from-literal=oidc_auth_url=$OIDC_AUTH_URL  \
    --from-literal=oidc_token_url=$OIDC_TOKEN_URL \
    --from-literal=client_base_url=$CLIENT1_BASE_URL
```

and deploy the client:

```console
cd oidc-oauth2-katas/
kubectl apply -f kubernetes/client1.yaml
```

When the client POD is `Running`, visit the client at the URL you
stored in `$CLIENT1_BASE_URL`.

### Using Tokens with Curl

Login to get tokens and export them in the terminal:

```console
export ID_TOKEN=<xxx>
export ACCESS_TOKEN=<yyy>
export REFRESH_TOKEN=<zzz>
```

Next, we use the OIDC discovery endpoint to find the URL where we can fetch userinfo:

```console
export USERINFO_EP=`curl -s https://keycloak.student$USER_NUM.$TRAINING_NAME.eficode.academy/auth/realms/myrealm/.well-known/openid-configuration | jq -r .userinfo_endpoint`
```

Userinfo is a 'protected resource', i.e. we need to provide the access
token in an `Authorization header` to access this information. Use the
following to do this from the terminal:

```console
curl -H "Authorization: Bearer $ACCESS_TOKEN" $USERINFO_EP | jq .
```

and you should see detailed user information:

```
{
  "sub": "ae2e5feb-44dd-49cd-96cd-dd68deee7c0c",
  "email_verified": true,
  "name": "Aname1 Alastname1",
  "preferred_username": "user1",
  "given_name": "Aname1",
  "family_name": "Alastname1",
  "email": "user1@example.com"
}
```

Repeat the `curl` command, but try with e.g. the ID token or an
invalid token to see the result.

Compare the information we got above with the content of the ID token:

```console
echo -n $ID_TOKEN | cut -d. -f2 | base64 -d | jq .
```

The ID-token may contain the same claims as returned from the userinfo
endpoint, however, this is not guaranteed. To keep the ID-token small,
identity providers are allowed to only include a minimal set of claims
in the ID-token, i.e. for a general OIDC-based client it is advised to
rely on the userinfo endpoint for extended user information. See
[ID-token](https://openid.net/specs/openid-connect-core-1_0.html#IDToken)
and [Standard
claims](https://openid.net/specs/openid-connect-core-1_0.html#StandardClaims)
for details.

In exercise [Confidential Client with Authorization Code
Flow](confidential-client-auth-code-flow.md) for simplicity we
displayed the 'logged in as' username using the ID-token claim
`preferred_username`. However, as noted above, ideally we should fetch
this information from the userinfo endpoint.

### Introspecting Tokens

The identity provider allow us to query for information about the
three tokens we got through an 'introspection endpoint'. We find the
introspection endpoint using OIDC discovery as follows:

```console
export INTROSPECTION_EP=`curl -s https://keycloak.student$USER_NUM.$TRAINING_NAME.eficode.academy/auth/realms/myrealm/.well-known/openid-configuration | jq -r .introspection_endpoint`
```

Lets introspect our access and refresh tokens:

```console
curl --data "client_id=$CLIENT1_ID&client_secret=$CLIENT1_SECRET&token=$ACCESS_TOKEN" $INTROSPECTION_EP | jq .
```

> If you get an error while using the access token, its most likely because the access token has expired. To solve this, use the client to logout and login again to get fresh tokens.

```
{
  "active": true,
  "scope": "openid profile email",
  ...
  "name": "Aname1 Alastname1",
  "given_name": "Aname1",
  "family_name": "Alastname1",
  "preferred_username": "user1",
  "email": "user1@example.com",
  "email_verified": true,
  "username": "user1",
}
```

```console
curl --data "client_id=$CLIENT1_ID&client_secret=$CLIENT1_SECRET&token=$REFRESH_TOKEN" $INTROSPECTION_EP | jq .
```

```
{
  "active": true
  "scope": "openid profile email",
  "exp": 1626236894,
  ...
  "sub": "ae2e5feb-44dd-49cd-96cd-dd68deee7c0c",
  "typ": "Refresh",
  "client_id": "client1",
  "username": null,
}

```

Of particular interest here is the `active` field, which indicate that
the token has not expired or been revoked.

The token introspection endpoint returns a [standardized
response](https://datatracker.ietf.org/doc/html/rfc7662#section-2.2)
however, only the `active` field is guaranteed in the response.

#### Is the Access Token a JWT?

To decode the access token as a JWT, use the following command:

```console
echo -n $ACCESS_TOKEN | cut -d. -f2 | base64 -d | jq .
```

Access tokens are not required to be JWTs, however, often they are and
this is also the case for KeyCloak.

Is the refresh token a JWT?

### Refreshing Tokens

With the refresh token, we can refresh our access token (and possibly
ID-token and refresh token as well). This is done through the
token endpoint. As from the previous exercise, store the identity
provider token endpoint in an environment variable:

```console
export OIDC_TOKEN_URL=`curl -s https://keycloak.student$USER_NUM.$TRAINING_NAME.eficode.academy/auth/realms/myrealm/.well-known/openid-configuration | jq -r .token_endpoint`
```

Next, issue a refresh request using `grant_type=refresh_token` and specifying the current refresh token:

```console
curl --data "client_id=$CLIENT1_ID&client_secret=$CLIENT1_SECRET&grant_type=refresh_token&refresh_token=$REFRESH_TOKEN" $OIDC_TOKEN_URL | jq .
```

This request return at least a new access token. It may also return a
new ID-token and refresh token, but this is not required by the OIDC
standard. If new ID/refresh tokens are returned, they should be used
going forward, and the old ones discarded.  E.g. if we introspect the
old access tokens which we have in the `ACCESS_TOKEN` environment
variable:

```console
curl --data "client_id=$CLIENT1_ID&client_secret=$CLIENT1_SECRET&token=$ACCESS_TOKEN" $INTROSPECTION_EP | jq .
```

we may get the result that it is no longer active:

```
{
  "active": false
}
```

Note, however, that revoking old access/refresh tokens when issuing
new tokens are defined as a `MAY` in the standards, i.e. it is not
guaranteed. KeyCloak currently DOES NOT revoke tokens, but many other
identity providers do.

### Re-validating User Login

Above we refreshed the access token using just client credentials and our
refresh token. We did not involve the user/browser.

A new ID token does not signify that the user still has a login
session through the browser. The client can continue to refresh tokens
even after the user has closed the browser and similarly continue to
access whatever the access token protects. This is an example of
**access being delegated from the user to the client**.

The user login authentication session exists between the user/browser
and the identity provider. The client does not know the status of this
session. The only way for a server-side client to validate if the user
still has a valid session is to re-authenticate, e.g. re-do the
authorization code flow login.

> With in-browser Javascript we can do more, but that is not within the scope of this exercise.

To see current user login sessions from a KeyCloak perspective, go to
KeyCloak and in the left-hand menu select `Users` and then `View all
users` in the top menu. Next, click on the user ID of the user
logged-in and then `Sessions` in the top menu. Next, you will see the
following (do not press the `Logout` button yet!):

> ![User login sessions](images/keycloak-user-sessions-anno.png)

The client have a button `Check Login Status`, which re-authenticates using the authorization code flow with two extra parameters:

- `prompt=none`, i.e. do not prompt the user for login, we prefer an error if user is no longer logged-in.
- `id_token_hint=xxx`, this is the user for which we want to silently log-in.

To see this in action, watch the client logs with the command below and press the `Check Login Status` button.

```console
kubectl logs -f -l app=client1
```

In the logs you should see the following (slightly edited for brevity):

```
Redirecting login to identity provider https://keycloak.userX..../openid-connect/auth?response_type=code&...&id_token_hint=XXXX&prompt=none
```

You will also see that as long as the user have a login session with
KeyCloak, the silent authorization successfully issues a new
ID-token. Try selecting `Check Login Status` a few more times and observe the tokens being refreshed.

Try selecting `Logout` in the KeyCloak user session view.

The client can detect the user logout at the identity provider by
introspecting the tokens, e.g. here using the ID-token:

```console
export ID_TOKEN=<xxx>    # Update with newest ID token from client UI
curl --data "client_id=$CLIENT1_ID&client_secret=$CLIENT1_SECRET&token=$ID_TOKEN" $INTROSPECTION_EP | jq .
```

We will now see, that the ID token is no longer active:

```
{
  "active": false
}
```

Also, if you retry 'Check Login Status' in the client you will now be
prompted for full login because the client observes an error in the
authorization code flow.

Login and continue below for how to logout from the identity provider from the client.

### Client-side Logout

Logout can also be performed from the client-side. Again, the identity
provider provide an URL, which we can find from the OIDC
configuration as `end_session_endpoint`:

```console
export OIDC_END_SESSION_EP=`curl -s https://keycloak.student$USER_NUM.$TRAINING_NAME.eficode.academy/auth/realms/myrealm/.well-known/openid-configuration | jq -r .end_session_endpoint`
```

Identity provider logout from the client is then achieved with an
`id_token_hint` parameter to indicate who is logging out:

```console
export ID_TOKEN=<xxx>    # Update with newest ID token from client UI
curl "$OIDC_END_SESSION_EP?id_token_hint=$ID_TOKEN"
```

<details>
<summary>:question:Is this proper use of the ID token?</summary>

> Generally the audience of the ID token is the client, i.e. its only intended to be used by the client. The access token is used to access protected resources like the `/userinfo` endpoint. Hence one could think that 'deleting' our login session at the identity provider using the ID token is a bit strange.
</details>

<details>
<summary>:question:Can you think of any reason why the ID token is used for logout?</summary>

>OIDC is about identity and authentication (who we are). A login session is an authentication 'channel' between browser and identity provider. Access tokens are authorizing access to protected resources and does not denote an active login session.
</details>


### Clean up

```console
kubectl delete -f kubernetes/client1.yaml
kubectl delete secret client1
kubectl delete configmap client1
```
