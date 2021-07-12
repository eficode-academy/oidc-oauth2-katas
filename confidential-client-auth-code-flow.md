# Confidential Client with Authorization Code Flow

## Learning Goals

- Configure a confidential client to work with an OIDC identity provider
- Hands-on with the requests and responses of the authorization code flow
- Understanding ID-tokens/JWTs

## Introduction

This exercise demonstrate OIDC login using a non-SPA client (non
single-page application) also known as a confidential client. Login
will be using the 'authorization code flow', which is the recommended
approach for most situations.

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

The two latter can be obtained from our authorization server using
'OIDC Discovery' which is a mechanism to allow OIDC Authorization
servers to publish information on well-known URLs.

Assuming your KeyCloak instance is located at:

```
https://keycloak.user<X>.<training-name>.eficode.academy
```

then you can fetch the OIDC configuration with (assumeing your realm was named `myrealm`):

```console
curl -s https://keycloak.user<X>.<training-name>.eficode.academy/auth/realms/myrealm/.well-known/openid-configuration | jq
```

Specifically, the authorization and token URLs can be found with:

```console
curl -s https://keycloak.user1.mvl.eficode.academy/auth/realms/myrealm/.well-known/openid-configuration | jq .authorization_endpoint
curl -s https://keycloak.user1.mvl.eficode.academy/auth/realms/myrealm/.well-known/openid-configuration | jq .token_endpoint
```

If running the client locally, you might want to export the settings as environment variables:

```console
export CLIENT_ID=client1
export CLIENT_SECRET=xxx
export OIDC_AUTH_URL=`curl -s https://keycloak.user1.mvl.eficode.academy/auth/realms/myrealm/.well-known/openid-configuration | jq -r .authorization_endpoint`
export OIDC_TOKEN_URL=`curl -s https://keycloak.user1.mvl.eficode.academy/auth/realms/myrealm/.well-known/openid-configuration | jq -r .token_endpoint`
```

## Exercise

### Clean up
