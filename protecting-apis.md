# Protecting Resources and APIs

## Learning Goals

- Protecting a REST API with access tokens
- Fine-grained access control with token scopes
- Adding custom scopes in KeyCloak
- Using Role-based Access Control (RBAC)

## Introduction

In this exercise we will deploy a REST API that allow us to read and
write objects to an object store. When creating an object an ID is
assigned to the object, and the object can later be retrieved using
the ID. We can also read a list of IDs for all objects in the store.

The object store will support the following methods:

1. GET `/objects` - for reading a list of all objects
2. POST `/object` - for creating a new object
3. GET `/object/:id` - for reading a specific object using its ID

We will protect access to the API with access tokens obtained through
our client and perform operations against the API using `curl` and the
terminal, however, these operations could easily be implemented in the
client itself.

We will also protect different methods of the API using different
access token scopes and claims.

### Client v2: Using Open-Source Libraries for OIDC Logic

The previous exercises used a client that implemented the OIDC login
procedure itself for demonstration purposes, **it is generally advisable
to use well-maintained open-source libraries to implement the OIDC
logic.**

In this and following exercises the NodeJS client has been updated to
use [PassportJS](http://www.passportjs.org) to handle the OIDC
logic. The details of the PassportJS implementation is not important
for the exercises, however, it means that the exercise apply the
recommendation above about using a well-maintained open-source library
to implement the OIDC logic. The example client provided may also be a
good starting-point for new applications.

### API Implementation

The source of the NodeJS API object store implementation can be found
[here](object-store/src/index.js). Initially a single object is
created (around line 15):

```
objects[uuid.v4()] = {title: 'Test object'}
```

The API implementation use the same
[openid-client](https://www.npmjs.com/package/openid-client) library
as the client application that handles login. However, the API
implementation only use this library for OIDC discovery to find the
URL of the keys used to sign JWTs and to validate the signature on the
access-token JWTs used to access the API.

The API implementation is a standard NodeJS express
implementation. The core part is the following, which does the OIDC
discovery and installs a middleware that **only trusts JWTs issued
from the identity provider**:

```nodejs
// OIDC discovery to locate the JWKS URI used to validate JWTs
Issuer.discover(oidc_issuer_url)
    .then(function (issuer) {
	console.log('Discovered issuer %s %O', issuer.issuer, issuer.metadata);

        // Install JWT middleware using 'issuer.jwks_uri' and caching of keys
	app.use(jwt({
	    secret: jwksRsa.expressJwtSecret({
		jwksUri: issuer.jwks_uri,
		cache: true,  // Enable JWT key cache
		timeout: 3600 // Key cache timeout, seconds
	    }),
	    algorithms: [ 'RS256' ],
	    requestProperty: 'auth'
	    // Here we could check more 'static' properties
	    // audience: ...
	    // issuer: ...
	}));
```

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

Set the following URLs as environment variables:

```console
export OIDC_ISSUER_URL=https://keycloak.student$STUDENT_NUM.$TRAINING_NAME.eficode.academy/auth/realms/myrealm
export CLIENT1_BASE_URL=https://client1.student$STUDENT_NUM.$TRAINING_NAME.eficode.academy
echo $CLIENT1_BASE_URL
```

Note that instead of configuring `OIDC_AUTH_URL` and `OIDC_TOKEN_URL`
separately, the `v2` client use the OIDC discovery endpoint and
discovers these URLs automatically, i.e. it only needs an OIDC issuer
URL.

### Deploy Client

Create a Kubernetes `ConfigMap` and `Secret` for client configuration:

```console
kubectl create secret generic client1 \
    --from-literal=client_id=$CLIENT1_ID \
    --from-literal=client_secret=$CLIENT1_SECRET
kubectl create configmap client1 \
    --from-literal=oidc_issuer_url=$OIDC_ISSUER_URL  \
    --from-literal=client_base_url=$CLIENT1_BASE_URL
```

and deploy the client:

```console
kubectl apply -f kubernetes/client1-v2.yaml
```

### Deploy API

Create a Kubernetes `ConfigMap` for API configuration:

```console
kubectl create configmap api \
    --from-literal=oidc_issuer_url=$OIDC_ISSUER_URL
```

and deploy the API:

```console
kubectl apply -f kubernetes/protected-api.yaml
```

### Accessing the API

When the client and API PODs are `Running`, do a login through the
client (URL as stored in `CLIENT1_BASE_URL` above) to get tokens and
export the access token in the terminal:

```console
export ACCESS_TOKEN=<yyy>
```

For convenience, set an environment variable that holds the API endpoint

```console
export API_EP=https://api.student$STUDENT_NUM.$TRAINING_NAME.eficode.academy
```

Now we can access the API using the access token in an `Authorization`
header. To get a list of object IDs through the API use:

```console
curl -H "Authorization: Bearer $ACCESS_TOKEN" $API_EP/objects && echo ""
```

To read a specific object ID, use:

```console
export OBJID=`curl -s -H "Authorization: Bearer $ACCESS_TOKEN" $API_EP/objects | jq -r .[0]`
curl -H "Authorization: Bearer $ACCESS_TOKEN" $API_EP/object/$OBJID && echo ""
```

Initially the API/object store only holds a single object. To write
new objects use a `POST` operation:

```console
curl -X POST -H "Authorization: Bearer $ACCESS_TOKEN" --data '{"title":"Test object 2"}' -H "Content-Type: application/json" $API_EP/object
curl -X POST -H "Authorization: Bearer $ACCESS_TOKEN" --data '{"title":"Test object 3"}' -H "Content-Type: application/json" $API_EP/object
```

And list the object - we now have three objects:

```console
curl -H "Authorization: Bearer $ACCESS_TOKEN" $API_EP/objects && echo ""
```

Try leaving out the token or the `Authorization` header. This
illustrate we can access the API **as long as we provide an access
token from the identity provider the API trusts**.

### Using Scope to Gate Access to API

In this section we will improve access to the API through fine-grained
authorization such that we can control which tokens allow read and
write.

We will gate access based on the `scope` claim in the access token. To
see the `scope` of your current access token use this command:

```console
echo $ACCESS_TOKEN | cut -d. -f2 |base64 -d | jq .scope
```

Next, we will obtain an access token with scopes dedicated for read
and/or write access. The client accepts two optional scopes with a
`:read` and `:write` suffix. Use the following commands to get the
specific name of these scopes:

```
echo "https://api.student$STUDENT_NUM.$TRAINING_NAME.eficode.academy:read"
echo "https://api.student$STUDENT_NUM.$TRAINING_NAME.eficode.academy:write"
```


Next, go to the client, logout using the button in the top and before
logging-in again, add the scope with the `:read` suffix after `openid
profile`, e.g. (where `<X>` and `<name>` are your specific values):

```
openid profile https://api.student<X>.<name>.eficode.academy:read
```

After login, you should see the new scope in the access token with:

```console
export ACCESS_TOKEN=<xxx>
echo $ACCESS_TOKEN | cut -d. -f2 |base64 -d | jq .scope
```

#### Adding Scope to the API

The API is implemented as a NodeJS/Express application and the source is
found in [object-store/src/index.js](object-store/src/index.js).

Open `index.js` in an editor on the machine where you are running your
`kubectl` commands. Locate the `GET` for object-by-id. It looks like
this (around line 54):

```nodejs
	app.get('/object/:id',
		//allowScopes(['yyy']),
		(req, res) => {
		    const id = req.params.id;
		    res.send(objects[id]);
		});
```

The get-by-id method is gated by a (commented out) `allowScopes()`
function that are also in the `index.js` file (around line 72). This function ensures
that one or more scopes are present in the access token and generates
an error if not.

Before updating the API authorization code, run the following command
in a separate console to see API log output:

```console
kubectl logs -f -l app=api
```

Next, edit `object-store/src/index.js` and remove the `//` in front of
`allowScopes` (around line 55) **but keep the bogus `yyy` scope**. Since this is a scope we
do not have in our access token we should expect an error when trying
to access the API.

Save the file and use `kubectl cp` to copy the code changes to the running API
POD:

```console
kubectl cp object-store/src/index.js `kubectl get pods -l app=api -o=jsonpath='{.items[0].metadata.name}'`:/apps/object-store/src/
```

After this, you will see from the log output, that the API service is restarted.

Try fetching an object from the API similarly to what we did initially:

```console
export OBJID=`curl -s -H "Authorization: Bearer $ACCESS_TOKEN" $API_EP/objects | jq -r .[0]`
echo $OBJID
curl -H "Authorization: Bearer $ACCESS_TOKEN" $API_EP/object/$OBJID && echo ""
```

You should see the access being denied with:

```
{"message":"insufficient_scope","status":403}
```

Next, update `object-store/src/index.js` to require the new `:read`
scope we added, e.g. similarly to what is shown below (but with your specific scope) and use `kubectl
cp` to update the API POD.

```nodejs
	app.get('/object/:id',
		allowScopes(['https://api.student123.oidc.eficode.academy:read']),
		(req, res) => {
		    const id = req.params.id;
		    res.send(objects[id]);
		});
```

Retry the get-by-id operation, which should now succeed (since the API
has no persistence and creates random object IDs at startup, remember
to also update `OBJID`).

#### Role Based Access Control (RBAC)

Using scopes is a resource-centric approach since it concerns itself
with 'which resources are in scope of the access token'. An
alternative is focus on the user and their associated
role. OIDC/OAuth2 does not have a role concept, but identity providers
often provide this functionality (although the details of the
implementation vary).

In the following we will gate access to the API using *user roles*.
Our two users (`user1` and `user2`) have been configured with a role
each (`developer` and `sre` respectively).

We can see our users' role through the `.realm_access` claim:

```console
echo $ACCESS_TOKEN | cut -d. -f2 |base64 -d | jq .realm_access
```

You should see something like the following for `user1`:

```
{
  "roles": [
    "default-roles-myrealm",
    "developer",
    "offline_access",
    "uma_authorization"
  ]
}
```

where `developer` is the essential role assigned to `user1`.

> The claim name `.realm_access` is KeyCloak specific, other identity provides will use other claim names.

Since the JWT claims are just entries in a dictionary, there is no
fundamental difference in implementing access restrictions using roles
instead of scopes. The implementation follows closely the
`allowScope()` function. See the `allowRoles()` function around line
89.

Next, we modify the `GET` for object-by-id function to only allow
access given one of the roles you assigned users (around line 54). You
may even combine the scope and role access restrictions with something
like:

```nodejs
        app.get('/object/:id',
                allowScopes(['https://api.student123.oidc.eficode.academy:read']),
                allowRoles(['developer']),
                (req, res) => {
                    const id = req.params.id;
                    res.send(objects[id]);
                });
```

Deploy the code with the `kubectl cp` command shown above and try
accessing the API using access tokens from your two users in two
different roles. User `user2` should be unable to read an object by ID
since it does not have the role `developer`. Observe the result in the
logs when reading an object-by-id with a user without the required
roles.

### Optional Extras

Add write-protection to the API by adding the scope with suffix `:write` to the object-store `POST` method in the API.


### Clean up

```console
kubectl delete -f kubernetes/protected-api.yaml
kubectl delete cm api
kubectl delete -f kubernetes/client1-v2.yaml
kubectl delete cm client1
kubectl delete secret client1
```
