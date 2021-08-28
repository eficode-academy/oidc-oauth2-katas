# OIDC and OAuth2 Katas

Exercises for the [Eficode Academy](https://www.eficode.com/academy) OIDC/OAuth2 training.

## Exercise Overview

- [Confidential Client with Authorization Code Flow](confidential-client-auth-code-flow.md)
- [Using Tokens](using-tokens.md)
- [Protecting Resources and APIs](protecting-apis.md)
- [WIP: Using Authorizing Proxies](authorizing-proxy.md)
- [WIP: Protecting against CSRF Attacks](csrf-attacks.md)
- [Session Storage](session-storage.md)
- TODO: Protecting Browser-based Apps (SPAs)

## Software Components

- client-nodejs - A NodeJS client that implements the OIDC authorization code flow itself.
- client-nodejs-v2 - A NodeJS client that use a standard module to implement the OIDC authorization code flow.
- object-store - An object store that implement authorization policies using a standard OIDC module.
- object-store-v2 - An object store that relies on an external OAuth2 proxy to implement authentication and authorization.
- hazard-service - A service that demonstrate the CSRF attack against object-store-v2
