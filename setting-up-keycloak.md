# Setting up KeyCloak

This guide describes how to create a realm in KeyCloak, add a user and
a client configuration. This guide does not describe how to deploy
KeyCloak. You must have an URL for KeyCloak before using this
guide. If you are participating in an Eficode training, the URL will
look like the following:

```
https://keycloak.user<X>.<training-name>.eficode.academy
```

where `<X>` is your assigned user number and `<training-name>` is a
per-training specific name that your trainer will inform you about.

First, log into KeyCloak as administrator. This typically means use
the `admin` username and the password obtained from the following
command:

```console
kubectl get secret keycloak -o jsonpath='{.data.admin-password}' | base64 -d && echo
```

When logged in, move you mouse to the upper left corner and select
`Add realm` as shown below:

> ![KeyCloak add realm](images/keycloak-add-realm-anno.png)

Enter the realm name `myrealm` and click `Create`.

## Adding Users

Use the following procedure to configure one or more test users.

Select `Users` in the left-hand menu and then `Add user` in the right-hand side:

> ![KeyCloak add user](images/keycloak-add-user-anno.png)

Enter username, email, first and last name. Also, check the `Email Verified` toggle:

> ![KeyCloak specify user data](images/keycloak-add-user2-anno.png)

When done configuring the user, click `Save`.

Finally, set the user password. Select `Credentials` in the top menu,
enter a password and ensure that `Temporary` is set to `OFF`:

> ![KeyCloak specify user password](images/keycloak-add-user-set-pw-anno.png)

## Configuring Clients

To allow clients to login users and obtain tokens from Keycloak, they
must be configured first.

Select `Clients` in the left-hand menu and click `Create`:

> ![KeyCloak add client](images/keycloak-add-client-anno.png)

Next, give the client an ID, e.g. `client1` and add a root URL of
the application. Click `Save` when you have added client settings.

<details>
<summary>:bulb:Which client root URL should I use?</summary>

The client root URL depends on where you run the client application
and how you access it from your browser. If you use you laptop browser
and also run the client application on your laptop, the root URL might
be something like `http://localhost:5000`. For an Eficode training, you
will be running the clients on Kubernetes and your client URL will
look like the following:

```
https://client1.user<X>.<training-name>.eficode.academy
```

</details>

> ![KeyCloak specify client data](images/keycloak-add-client2-anno.png)

After having created a client, we are presented with further details
about the client. Scroll down and locate `Access Type`. Change it to
`confidential` as shown below. Click save when you have change the
access type.

> ![KeyCloak specify client data](images/keycloak-add-client-confidential-type-anno.png)

After having changed the client access type to `confidential`, we get
a `Credentials` tab in the top menu. Select the `Credentials` tab.

On the credentials page we see, that 'Client Authenticator' is set to
`Client Id and Secret` and we also see the secret which has been
assigned to the client. We will need this secret later, i.e. now you
know where to locate it.

> ![KeyCloak specify client data](images/keycloak-add-client-lookup-creds-anno.png)
