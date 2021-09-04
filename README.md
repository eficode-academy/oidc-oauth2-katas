# OIDC and OAuth2 Katas

Exercises for the [Eficode Academy](https://www.eficode.com/academy) *Securing APIs and Web Applications with OIDC and OAuth2* training.

## Exercise Overview

- [Confidential Client with Authorization Code Flow](confidential-client-auth-code-flow.md)
- [Using Tokens](using-tokens.md)
- [Protecting Resources and APIs](protecting-apis.md)
- [Using Authorizing Proxies](authorizing-proxy.md)
- [Protecting against CSRF Attacks](csrf-attacks.md)
- [Session Storage](session-storage.md)
- TODO: Protecting Browser-based Apps (SPAs)

## Software Components

- client-nodejs - A NodeJS client that implements the OIDC authorization code flow itself.
- client-nodejs-v2 - A NodeJS client that use a standard module to implement the OIDC authorization code flow.
- object-store - An object store that implement authorization policies using a standard OIDC module.
- object-store-v2 - An object store that relies on an external OAuth2 proxy to implement authentication and authorization.
- hazard-service - A service that demonstrate the CSRF attack against object-store-v2

## Infrastructure Prerequisites

These katas assume the availability of a Kubernetes cluster with some preconfigured services:

- A KeyCloak instance. No configuration of KeyCloak is necessary, we
  will configure KeyCloak with realm, clients and users in [Setting up
  KeyCloak](setting-up-keycloak.md).
- DNS, TLS and ingress routing from sub-domains `client1`, `client2`,
  `api` and `hazard` to Kubernetes services of the same name.