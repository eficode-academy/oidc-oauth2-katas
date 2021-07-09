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

## Exercise

### Clean up
