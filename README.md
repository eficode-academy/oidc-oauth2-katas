# OIDC and OAuth2 Katas

Exercises for the [Eficode Academy](https://www.eficode.com/academy) *OIDC and OAuth2 - Securing APIs and Web Applications* training.

## Exercise Overview

- [Confidential Client with Authorization Code Flow - Part 1](confidential-client-auth-code-flow.md)
- [Confidential Client with Authorization Code Flow - Part 2](confidential-client-auth-code-flow2.md)
- [Using Tokens](using-tokens.md)
- [Protecting Resources and APIs](protecting-apis.md)
- [Using Authorizing Proxies](authorizing-proxy.md)
- [Protecting against CSRF Attacks](csrf-attacks.md)
- [Session Storage](session-storage.md)
- [OIDC in Browser-based Apps (SPAs)](oidc-in-spas.md)

## Software Components

The exercises use the following software components:

- `client-nodejs` - A NodeJS client that implements the OIDC authorization code flow in a DIY fashion.
- `client-nodejs-v2` - A NodeJS client that use a Passport-based NodeJS module to implement the OIDC authorization code flow.
- `object-store` - An object store that implement authorization policies using a Passport-based module.
- `object-store-v2` - An object store that relies on an external OAuth2 proxy to implement authentication and authorization.
- `hazard-service` - A service that demonstrate the CSRF attack against object-store-v2
- `spa` - A browser-based applications using the backend-for-frontend pattern and writing to a protected object-store. The SPA consists of the following components:
  * `cdn` - A simple server for static SPA assets. Applies CSP.
  * `login` - A backend-for-frontend component that implements OIDC server-side
  * `api-gw` - A component that works together with the login/bff component for exchanging cookies for tokens. The api-gw interfaces to an upstream object store.
  * `object-store` - The same components as above, but this time accessed from the SPA through the `api-gw`.

For simplicity, these software components are built into a single
container image. See [Dockerfile](ci/Dockerfile) and
[image](https://hub.docker.com/repository/docker/praqma/oidc-oauth2-katas-client).

## Infrastructure Prerequisites

These katas assume the availability of a Kubernetes cluster with some pre-configured services:

- A KeyCloak deployment. No configuration of KeyCloak is necessary, we
  will configure KeyCloak with realm, clients and users in [Setting up
  KeyCloak](setting-up-keycloak.md). Exercises are suitable for use
  with other identity providers but descriptions are for KeyCloak.

- DNS, TLS and ingress routing from sub-domains `client1`, `client2`,
  `api` and `hazard` to Kubernetes services of the same name.

- DNS, TLS and ingress routing from sub-domain `spa` with path routing as follows:

   * `/api` routed to Kubernetes service `spa-api-gw`
   * `/login` routed to Kubernetes service `spa-login` with stripping of `/login` path prefix
   * `/` routed to Kubernetes service `spa-cdn`
