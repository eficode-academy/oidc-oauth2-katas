#!/bin/bash

# This script implements deployment of the various exercises and some basic testing


set -e

KATAS_PATH="oidc-oauth2-katas"

ACTION=${1:-""}

SUCCESSES=0
ERRORS=0

function common-setup-env {
    # These are a bit random - needs real idp values
    export CLIENT1_ID=client1
    if [ -z "$CLIENT1_SECRET" ]; then
        export CLIENT1_SECRET=123456789
    fi
    export OIDC_ISSUER_URL=https://keycloak.user$USER_NUM.$TRAINING_NAME.eficode.academy/auth/realms/myrealm
    export OIDC_AUTH_URL=`curl -s https://keycloak.user$USER_NUM.$TRAINING_NAME.eficode.academy/auth/realms/myrealm/.well-known/openid-configuration | jq -r .authorization_endpoint`
    export OIDC_TOKEN_URL=`curl -s https://keycloak.user$USER_NUM.$TRAINING_NAME.eficode.academy/auth/realms/myrealm/.well-known/openid-configuration | jq -r .token_endpoint`
}

function exercise-using-tokens-setup-env {
    common-setup-env
    export CLIENT1_BASE_URL=https://client1.user$USER_NUM.$TRAINING_NAME.eficode.academy
}

if [ $ACTION = "exercise-using-tokens-deploy" ]; then
    exercise-using-tokens-setup-env

    kubectl create secret generic client1 \
            --from-literal=client_id=$CLIENT1_ID \
            --from-literal=client_secret=$CLIENT1_SECRET
    kubectl create configmap client1 \
            --from-literal=oidc_auth_url=$OIDC_AUTH_URL  \
            --from-literal=oidc_token_url=$OIDC_TOKEN_URL \
            --from-literal=client_base_url=$CLIENT1_BASE_URL

    kubectl apply -f $KATAS_PATH/kubernetes/client1.yaml
    kubectl wait --for=condition=ready pod -l app=client1 --timeout=3600s
fi

if [ $ACTION = "exercise-using-tokens-undeploy" ]; then
    kubectl delete -f $KATAS_PATH/kubernetes/client1.yaml
    kubectl delete secret client1
    kubectl delete configmap client1
fi

if [ $ACTION = "exercise-using-tokens-test" ]; then
    exercise-using-tokens-setup-env
    HTTP_STATUS=$(curl -s $CLIENT1_BASE_URL -o /dev/null -w '%{http_code}')
    if [ "$HTTP_STATUS" != '200' ]; then
        echo "*** Error, got HTTP status $HTTP_STATUS"
        let ERRORS+=1
    else
        let SUCCESSES+=1
    fi
fi



function exercise-protecting-apis-setup-env {
    common-setup-env
    export CLIENT1_BASE_URL=https://client1.user$USER_NUM.$TRAINING_NAME.eficode.academy
    export API_EP=https://api.user$USER_NUM.$TRAINING_NAME.eficode.academy
}

if [ $ACTION = "exercise-protecting-apis-deploy" ]; then
    exercise-protecting-apis-setup-env

    kubectl create secret generic client1 \
            --from-literal=client_id=$CLIENT1_ID \
            --from-literal=client_secret=$CLIENT1_SECRET
    kubectl create configmap client1 \
            --from-literal=oidc_issuer_url=$OIDC_ISSUER_URL  \
            --from-literal=client_base_url=$CLIENT1_BASE_URL
    kubectl apply -f $KATAS_PATH/kubernetes/client1-v2.yaml
    kubectl create configmap api \
            --from-literal=oidc_issuer_url=$OIDC_ISSUER_URL
    kubectl apply -f $KATAS_PATH/kubernetes/protected-api.yaml

    kubectl wait --for=condition=ready pod -l app=client1 --timeout=3600s
    kubectl wait --for=condition=ready pod -l app=api --timeout=3600s
fi

if [ $ACTION = "exercise-protecting-apis-undeploy" ]; then
    kubectl delete -f $KATAS_PATH/kubernetes/protected-api.yaml
    kubectl delete cm api
    kubectl apply -f $KATAS_PATH/kubernetes/client1-v2.yaml
    kubectl delete cm client1
    kubectl delete secret client1
fi

if [ $ACTION = "exercise-protecting-apis-test" ]; then
    exercise-protecting-apis-setup-env

    HTTP_STATUS=$(curl -s $API_EP/objects -o /dev/null -w '%{http_code}')
    if [ "$HTTP_STATUS" != '403' ]; then
        echo "*** Error, got HTTP status $HTTP_STATUS"
        let ERRORS+=1
    else
        let SUCCESSES+=1
    fi
fi

function exercise-oidc-in-spas-setup-env {
    common-setup-env
    export DOMAIN=user$USER_NUM.$TRAINING_NAME.eficode.academy
    export SPA_BASE_URL=https://spa.$DOMAIN
}

if [ $ACTION = "exercise-oidc-in-spas-deploy" ]; then
    exercise-oidc-in-spas-setup-env

    kubectl create configmap spa-cdn \
            --from-literal=csp_connect_sources="$SPA_BASE_URL"
    kubectl apply -f $KATAS_PATH/kubernetes/spa-cdn.yaml

    kubectl create secret generic client1 \
            --from-literal=client_id=$CLIENT1_ID \
            --from-literal=client_secret=$CLIENT1_SECRET
    kubectl create configmap spa-login \
            --from-literal=oidc_issuer_url=$OIDC_ISSUER_URL  \
            --from-literal=redirect_url=$SPA_BASE_URL
    kubectl apply -f $KATAS_PATH/kubernetes/spa-login.yaml

    kubectl create configmap api \
            --from-literal=oidc_issuer_url=$OIDC_ISSUER_URL
    kubectl apply -f $KATAS_PATH/kubernetes/protected-api.yaml

    kubectl apply -f $KATAS_PATH/kubernetes/spa-api-gw.yaml

    kubectl wait --for=condition=ready pod -l app=spa-cdn --timeout=3600s
    kubectl wait --for=condition=ready pod -l app=spa-login --timeout=3600s
    kubectl wait --for=condition=ready pod -l app=spa-api-gw --timeout=3600s
    kubectl wait --for=condition=ready pod -l app=api --timeout=3600s
    kubectl wait --for=condition=ready pod -l app=session-store --timeout=3600s
fi

if [ $ACTION = "exercise-oidc-in-spas-undeploy" ]; then
    kubectl delete -f $KATAS_PATH/kubernetes/spa-cdn.yaml
    kubectl delete -f $KATAS_PATH/kubernetes/spa-login.yaml
    kubectl delete -f $KATAS_PATH/kubernetes/spa-api-gw.yaml
    kubectl delete -f $KATAS_PATH/kubernetes/protected-api.yaml
    kubectl delete cm spa-cdn spa-login api
    kubectl delete secret client1
fi

if [ $ACTION = "exercise-oidc-in-spas-test" ]; then
    exercise-oidc-in-spas-setup-env

    HTTP_STATUS=$(curl -s $SPA_BASE_URL -o /dev/null -w '%{http_code}')
    if [ "$HTTP_STATUS" != '200' ]; then
        echo "*** Error, got HTTP status $HTTP_STATUS"
        let ERRORS+=1
    else
        let SUCCESSES+=1
    fi
fi

if [ $ERRORS -eq 0 ]; then
    echo "Success - no errors detected ($SUCCESSES successes)"
else
    echo "*** Failed - $ERRORS error(s) found ($SUCCESSES successes)"
fi
