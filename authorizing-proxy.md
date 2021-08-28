# Using Authorizing Proxies

## Learning Goals

- provide a list of goals to learn here

## Introduction

In exercise [Protecting Resources and APIs](protecting-apis.md) the
OIDC/OAuth2 authorization flow was implemented using a NodeJS Express
middleware, i.e. a module imported into the application itself.

This exercise demonstrate an architectural pattern, where the
OIDC/OAuth2 authorization flow and session cookie management is moved
out from the application itself and into the surrounding
infrastructure.

The application will be protected by an authorizing proxy, that only
allow authenticated and/or authorized traffic towards the
application. Moving this functionality out from the application have
some benefits:

- The authentication and/or authorization can be generalized and not every application need to implement it.
- Having a single secure entry point for our application makes it more likely that we 'get it right' compared to if we have multiple services and we need to test and verify all implementations.

However, there is also some drawbacks

- Authentication and authorization policies are dictated by what the authorizing proxy supports, i.e. it may be difficult to implement fine-grained policies.
- The proxy may be deployed/managed by a different team than the service it protects, i.e. changing policies or debugging access issues could become more difficult.




## Exercise

The authorizing proxy will pass authentication/authorization details
to our upstream application through HTTP headers. To inspect these we
will for this exercise use the
[httpbin](https://github.com/postmanlabs/httpbin) tool as the
application we protect. In the following exercise [Protecting against
CSRF Attacks](csrf-attacks.md) we will use our own service protected
by the authorizing proxy to demonstrate that the proxy does not
protect against such attacks.

Deploy `httpbin` with:

```console
kubectl apply -f kubernetes/httpbin.yaml
```

This creates a Kubernetes deployment and service (named `httpbin`),
however, this service is only accessible inside the kubernetes
cluster.  Externally we should only be able to access the authorizing
proxy and the proxy should only allow authorized access the httpbin.

Next we deploy OAuth2 proxy in front of httpbin to provide this
external access.

First, set some variables that help us build URLs:

```console
export USER_NUM=<X>             # Use your assigned user number
export TRAINING_NAME=<xxx>      # Get this from your trainer
```

For convenience, set the following variables:

```console
export CLIENT1_ID=client1
export CLIENT1_SECRET=<xxx>     # This is your client1 'credential'
export OIDC_ISSUER_URL=https://keycloak.user$USER_NUM.$TRAINING_NAME.eficode.academy/auth/realms/myrealm
```

Externally we make OAuth2 proxy available at our externally
available `oauth2-proxy` DNS and we want the upstream (the service behind
OAuth2 proxy) to be the DNS name `httpbin`, which is only
available/resolvable inside the Kubernetes cluster. I.e. setup the to
URLs as environment variables:

> In real production environments you would probably not use a DNS name like `oauth2-proxy`. Instead you would probably make the proxy available at the client DNS name such that its naturally integrated in the application. Additionally you could [add a theme](https://github.com/MichaelVL/oauth2-proxy-themed) to the proxy.

```console
export OAUTH2_PROXY_EP=https://oauth2-proxy.user$USER_NUM.$TRAINING_NAME.eficode.academy
export OAUTH2_PROXY_UPSTREAM=http://httpbin:80
```





```
kubectl create secret generic client1 \
    --from-literal=client-id=$CLIENT1_ID \
    --from-literal=client-secret=$CLIENT1_SECRET \
    --from-literal=cookie-secret=abcdefgh12345678
```

```console
cat kubernetes/oauth2-proxy-values.yaml | envsubst > my-values.yaml
cat my-values.yaml
```


```
config:
  existingSecret: client1
  configFile: |-
    ...
    email_domains = [ "example.com" ]
```



```console
helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests
helm install oauth2-proxy oauth2-proxy/oauth2-proxy --values my-values.yaml
```

Finally, you can login through OAuth2 proxy by opening the URL we
stored in the `OAUTH2_PROXY_EP` environment variable above. You should
see something like:

> ![OAuth2 proxy login screen](images/oauth2-proxy-login.png)





```
    ...
    "X-Forwarded-Email": "user1@example.com",
    "X-Forwarded-Preferred-Username": "user1",
    "X-Forwarded-User": "ea62d4cb-dc5e-4c7b-8ab3-4f166e4b9c17"
```

We saw above, that the authorization policy used by OAuth2 proxy was
that users should have an email in the domain `example.com`.

Next, to show that this is in fact the policy used by OAuth2 proxy,
try out the following two scenarios, which we expect to be unable to
access the protected service:

- A user with an un-verified email
- A user with an email in another domain, e.g. `@notexample.com`

To sign-out in OAuth2 proxy, you can access the URL stored in
`OAUTH2_PROXY_EP` and appending `/oauth2/sign_out`. This will,
however, only clear the OAuth2 proxy session. To also logout from the
KeyCloak session, use the KeyCloak interface as we did in the [Using
Tokens](using-tokens.md) exercise.

<details>
<summary>:bulb: Implementing full logout</summary>
It is possible to logout from both OAuth2 proxy and KeyCloak by appending a redirection URL to the `/auth2/sign_out` URL. See https://oauth2-proxy.github.io/oauth2-proxy/docs/features/endpoints/#sign-out.
</details>




### Clean up

```console
helm delete oauth2-proxy
kubectl delete secret client1
kubectl delete -f kubernetes/httpbin.yaml
```
