# Using Authorizing Proxies

## Learning Goals

- Understand and use the *authorizing proxy* architectural pattern
- Deploy [OAuth2-proxy](https://github.com/oauth2-proxy/oauth2-proxy) with Helm configured to authenticate users from an OIDC provider.
- Configuring our application as an upstream service protected behind the authorizing proxy.

## Introduction

In exercise [Protecting Resources and APIs](protecting-apis.md) the
OIDC/OAuth2 authorization code flow was implemented using a NodeJS
Express middleware, i.e. a module imported into the application
itself.

This exercise demonstrate an architectural pattern, where the
OIDC/OAuth2 authorization flow and session cookie management is moved
out from the application itself and into the surrounding
infrastructure.

The application will be protected by the authorizing proxy, which only
allow authenticated and/or authorized traffic towards the
application. Moving this functionality out from the application have
some benefits:

- The authentication and/or authorization can be generalized and every application does not need to implement it.
- Having a single secure entry point for our application makes it more likely that we 'get security right' compared to if we have multiple services and we need to test and verify all implementations of security.
- The authorizing proxy can be managed by a different team than the protected service. This provides a convenient separation of concerns.

However, there is also some drawbacks

- Authentication and authorization policies are dictated by what the authorizing proxy supports, i.e. it may be difficult to implement fine-grained policies.
- The proxy may be deployed/managed by a different team than the service it protects, i.e. changing policies or debugging access issues could become more difficult due to slow turn-around time or missing access to e.g. proxy logs.

The authorizing proxy will pass authentication/authorization details
to our upstream application through HTTP headers. To inspect these we
will for this exercise use the
[httpbin](https://github.com/postmanlabs/httpbin) tool as the
service we protect.

## Prerequisites

This exercise use the following environment variables. **They will
already be configured for Eficode-run trainings**:

```
STUDENT_NUM
TRAINING_NAME
CLIENT1_ID
CLIENT1_SECRET
```

Use the following command to inspect your environment variables:

```console
env | egrep 'STUDENT_NUM|TRAINING_NAME|^CLIENT[12]_|^SPA_|^OIDC_' | sort
```

Exercises assume you have changed to the katas folder:

```console
cd oidc-oauth2-katas
```

## Exercise

For this exercise we will configure the OAuth2-proxy to allow only
'users with validated emails in the domain `example.com` to access the
protected service'.

### Deploy HTTPBin

Deploy `httpbin` with:

```console
kubectl apply -f kubernetes/httpbin.yaml
```

This creates a Kubernetes deployment and service (named `httpbin`),
however, this service is only accessible inside the kubernetes
cluster.

### Deploy OAuth2-proxy

Next we deploy OAuth2-proxy in front of httpbin to provide this
external access.

Set the following URL as an environment variable:

```console
export OIDC_ISSUER_URL=https://keycloak.student$STUDENT_NUM.$TRAINING_NAME.eficode.academy/auth/realms/myrealm
```

OAuth2-proxy will interact with the identity-provider at
`OIDC_ISSUER_URL` to authenticate users, we will have to create a
secret with the client ID and secret. Also, OAuth2-proxy will manage a
session through signed cookies, i.e. it requires a secret for cookie
signatures. Thus, we create a secret for OAuth2-proxy with:

```console
kubectl create secret generic client1 \
    --from-literal=client-id=$CLIENT1_ID \
    --from-literal=client-secret=$CLIENT1_SECRET \
    --from-literal=cookie-secret=abcdefgh12345678
```

Externally we make OAuth2-proxy available at our externally available
`client1` DNS sub-domain and we want the 'upstream' (the service
behind OAuth2-proxy) to be the Kubernetes-internal DNS name
`httpbin`. I.e. setup the two URLs as environment variables:

```console
export OAUTH2_PROXY_EP=https://client1.student$STUDENT_NUM.$TRAINING_NAME.eficode.academy
export OAUTH2_PROXY_UPSTREAM=http://httpbin:80
```

Next we configure OAuth2-proxy Helm chart values with URLs from the
environment variables above:

```console
cat kubernetes/oauth2-proxy-values.yaml | envsubst > my-values.yaml
cat my-values.yaml
```

Inspect the generated Helm chart values.

- Knowing that OAuth2-proxy implements the OIDC authorization code
flow, the `oidc_issuer_url` and `redirect_url` parameters should look
familiar.
- The `upstreams` parameter is the service behind the proxy, i.e. this is
our `httpbin` Kubernetes service.
- Finally, the `email_domains` parameter is the authorization policy
that OAuth2-proxy applies, i.e. any user with a verified email from
the given domain are authorized to access the protected service.

Next, install OAuth2-proxy with Helm:

```console
helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests
helm install client1 oauth2-proxy/oauth2-proxy --values my-values.yaml
```

When the OAuth2-proxy and object store PODs are `Running`, access the
URL we stored in the `OAUTH2_PROXY_EP` environment variable
above. First you will see the OAuth2-login page, which looks like
this:

> ![OAuth2-proxy login screen](images/oauth2-proxy-login.png)

Our test users have a verified email in the domain `example.com`,
i.e. you should be able to login and access the `httpbin`
service. Select the `Request Inspection` and `/headers` option as
shown below:

> ![Httpbin service](images/httpbin-request-anno.png)

Select the `GET` and `Try it out` buttons and finally `Execute`. This
will trigger a request to `httpbin` that returns in the `Response
body` and headers `httpbin` received on the incoming request. This
allow us to see the metadata passed from OAuth2-proxy to our upstream
service. In the `Response body` we should see the following
information which is userdata OAuth2-proxy obtained from the OIDC
login:

```
    ...
    "X-Forwarded-Email": "user1@example.com",
    "X-Forwarded-Preferred-Username": "user1",
    "X-Forwarded-User": "ea62d4cb-dc5e-4c7b-8ab3-4f166e4b9c17"
```

We saw above, that the authorization policy used by OAuth2-proxy was
that users should have an email in the domain `example.com`.

Next, to show that this is in fact the policy used by OAuth2-proxy,
try out the following two scenarios, which we expect to be unable to
access the protected service:

- A user with an email in another domain (use user `user3`, which have email `user3@notexample.com`
- A user with an un-verified email (use user `user4`)

Before trying these, you need to sign-out in OAuth2-proxy.

To sign-out in OAuth2-proxy, you can access the URL stored in
`OAUTH2_PROXY_EP` and appending `/oauth2/sign_out`.

```console
echo "Sign out URL: $OAUTH2_PROXY_EP/oauth2/sign_out"
```

This will,
however, only clear the OAuth2-proxy session. To also logout from the
KeyCloak session, use the KeyCloak interface as we did in the [Using
Tokens](using-tokens.md) exercise.

<details>
<summary>:mag: Implementing full logout</summary>
> It is possible to logout from both OAuth2-proxy and KeyCloak by appending a redirection URL to the `/auth2/sign_out` URL. See https://oauth2-proxy.github.io/oauth2-proxy/docs/features/endpoints/#sign-out.
</details>

### Clean up

```console
helm delete client1
kubectl delete secret client1
kubectl delete -f kubernetes/httpbin.yaml
```
