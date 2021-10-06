#!/bin/bash

# This script implements deployment of the various exercises and some basic testing
# It relies on markdown blocks to be converted to bash using:
# tests/markdown2bash.py *.md > tests/markdown-blocks.sh

set -e

SELF_PATH=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
KATAS_PATH="$SELF_PATH/.."

ACTION=${1:-""}

SUCCESSES=0
ERRORS=0

source $SELF_PATH/markdown-blocks.sh

function common-setup-env {
    # These are a bit random - needs real idp values
    export CLIENT1_ID=client1
    export SPA_CLIENT_ID=spa
    if [ -z "$CLIENT1_SECRET" ]; then
        export CLIENT1_SECRET=123456789
    fi
    if [ -z "$SPA_CLIENT_SECRET" ]; then
        export SPA_CLIENT_SECRET=123456789
    fi
    export OIDC_ISSUER_URL=https://keycloak.user$USER_NUM.$TRAINING_NAME.eficode.academy/auth/realms/myrealm
    export OIDC_AUTH_URL=`curl -s https://keycloak.user$USER_NUM.$TRAINING_NAME.eficode.academy/auth/realms/myrealm/.well-known/openid-configuration | jq -r .authorization_endpoint`
    export OIDC_TOKEN_URL=`curl -s https://keycloak.user$USER_NUM.$TRAINING_NAME.eficode.academy/auth/realms/myrealm/.well-known/openid-configuration | jq -r .token_endpoint`
}

function exercise-confidential-client-auth-code-flow-setup-env {
    common-setup-env
    confidential-client-auth-code-flow.md-exercise-block4
    confidential-client-auth-code-flow.md-exercise-block6
}

function exercise-confidential-client-auth-code-flow-deploy {
    exercise-confidential-client-auth-code-flow-setup-env

    confidential-client-auth-code-flow.md-exercise-block7
    confidential-client-auth-code-flow.md-exercise-block8

    kubectl wait --for=condition=ready pod -l app=client1 --timeout=60s
    sleep 10
}

function exercise-confidential-client-auth-code-flow-undeploy {
    confidential-client-auth-code-flow.md-clean-up-block1
}

function exercise-confidential-client-auth-code-flow-test {
    exercise-confidential-client-auth-code-flow-setup-env
    HTTP_STATUS=$(curl -s $CLIENT1_BASE_URL -o /dev/null -w '%{http_code}')
    if [ "$HTTP_STATUS" != '200' ]; then
        echo "*** Error, got HTTP status $HTTP_STATUS"
        let ERRORS+=1
    else
        let SUCCESSES+=1
    fi
}

function exercise-using-tokens-setup-env {
    common-setup-env
    export CLIENT1_BASE_URL=https://client1.user$USER_NUM.$TRAINING_NAME.eficode.academy
}

function exercise-using-tokens-deploy {
    exercise-using-tokens-setup-env

    kubectl create secret generic client1 \
            --from-literal=client_id=$CLIENT1_ID \
            --from-literal=client_secret=$CLIENT1_SECRET
    kubectl create configmap client1 \
            --from-literal=oidc_auth_url=$OIDC_AUTH_URL  \
            --from-literal=oidc_token_url=$OIDC_TOKEN_URL \
            --from-literal=client_base_url=$CLIENT1_BASE_URL

    kubectl apply -f $KATAS_PATH/kubernetes/client1.yaml
    kubectl wait --for=condition=ready pod -l app=client1 --timeout=60s
    sleep 10
}

function exercise-using-tokens-undeploy {
    kubectl delete -f $KATAS_PATH/kubernetes/client1.yaml
    kubectl delete secret client1
    kubectl delete configmap client1
}

function exercise-using-tokens-test {
    exercise-using-tokens-setup-env
    HTTP_STATUS=$(curl -s $CLIENT1_BASE_URL -o /dev/null -w '%{http_code}')
    if [ "$HTTP_STATUS" != '200' ]; then
        echo "*** Error, got HTTP status $HTTP_STATUS"
        let ERRORS+=1
    else
        let SUCCESSES+=1
    fi
}

function exercise-protecting-apis-setup-env {
    common-setup-env
    export CLIENT1_BASE_URL=https://client1.user$USER_NUM.$TRAINING_NAME.eficode.academy
    export API_EP=https://api.user$USER_NUM.$TRAINING_NAME.eficode.academy
}

function exercise-protecting-apis-deploy {
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

    kubectl wait --for=condition=ready pod -l app=client1 --timeout=60s
    kubectl wait --for=condition=ready pod -l app=api --timeout=60s
    sleep 10
}

function exercise-protecting-apis-undeploy {
    kubectl delete -f $KATAS_PATH/kubernetes/protected-api.yaml
    kubectl delete cm api
    kubectl delete -f $KATAS_PATH/kubernetes/client1-v2.yaml
    kubectl delete cm client1
    kubectl delete secret client1
}

function exercise-protecting-apis-test {
    exercise-protecting-apis-setup-env

    HTTP_STATUS=$(curl -s $API_EP/objects -o /dev/null -w '%{http_code}')
    if [ "$HTTP_STATUS" != '401' ]; then
        echo "*** Error, got HTTP status $HTTP_STATUS"
        let ERRORS+=1
    else
        let SUCCESSES+=1
    fi
}


function exercise-csrf-attacks-setup-env {
    common-setup-env

    csrf-attacks.md-exercise-block3
    csrf-attacks.md-exercise-block5
}

function exercise-csrf-attacks-deploy {
    exercise-csrf-attacks-setup-env

    csrf-attacks.md-exercise-block1
    csrf-attacks.md-exercise-block4
    csrf-attacks.md-exercise-block6
    csrf-attacks.md-exercise-block7

    csrf-attacks.md-setting-up-the-hazard-block1
    csrf-attacks.md-setting-up-the-hazard-block2

    kubectl wait --for=condition=ready pod -l app=oauth2-proxy --timeout=60s
    kubectl wait --for=condition=ready pod -l app=object-store-v2 --timeout=60s
    kubectl wait --for=condition=ready pod -l app=hazard --timeout=60s
    sleep 10
}

function exercise-csrf-attacks-undeploy {
    exercise-csrf-attacks-setup-env
    csrf-attacks.md-clean-up-block1
}

function exercise-csrf-attacks-test {
    exercise-csrf-attacks-setup-env
}



function exercise-oidc-in-spas-setup-env {
    common-setup-env
    export DOMAIN=user$USER_NUM.$TRAINING_NAME.eficode.academy
    export SPA_BASE_URL=https://spa.$DOMAIN
}

function exercise-oidc-in-spas-deploy {
    exercise-oidc-in-spas-setup-env

    oidc-in-spas.md-deploy-spa-block1
    oidc-in-spas.md-deploy-bff-block2
    oidc-in-spas.md-deploy-bff-block3
    oidc-in-spas.md-deploy-api-block1
    oidc-in-spas.md-deploy-api-block2
    oidc-in-spas.md-deploy-api-gateway-block1

    kubectl wait --for=condition=ready pod -l app=spa-cdn --timeout=60s
    kubectl wait --for=condition=ready pod -l app=spa-login --timeout=60s
    kubectl wait --for=condition=ready pod -l app=spa-api-gw --timeout=60s
    kubectl wait --for=condition=ready pod -l app=api --timeout=60s
    kubectl wait --for=condition=ready pod -l app=session-store --timeout=60s
    sleep 10
}

function exercise-oidc-in-spas-undeploy {
    oidc-in-spas.md-clean-up-block1
}

function exercise-oidc-in-spas-test {
    exercise-oidc-in-spas-setup-env

    HTTP_STATUS=$(curl -s $SPA_BASE_URL -o /dev/null -w '%{http_code}')
    if [ "$HTTP_STATUS" != '200' ]; then
        echo "*** Error, got HTTP status $HTTP_STATUS"
        let ERRORS+=1
    else
        let SUCCESSES+=1
    fi
}

function test-all {

    exercise-confidential-client-auth-code-flow-deploy
    exercise-confidential-client-auth-code-flow-test
    exercise-confidential-client-auth-code-flow-undeploy

    exercise-using-tokens-deploy
    exercise-using-tokens-test
    exercise-using-tokens-undeploy

    exercise-protecting-apis-deploy
    exercise-protecting-apis-test
    exercise-protecting-apis-undeploy

    exercise-csrf-attacks-deploy
    exercise-csrf-attacks-test
    exercise-csrf-attacks-undeploy

    exercise-oidc-in-spas-deploy
    exercise-oidc-in-spas-test
    exercise-oidc-in-spas-undeploy
}

while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        exercise-confidential-client-auth-code-flow-deploy)
            exercise-confidential-client-auth-code-flow-deploy
        ;;
        exercise-confidential-client-auth-code-flow-undeploy)
            exercise-confidential-client-auth-code-flow-undeploy
        ;;
        exercise-confidential-client-auth-code-flow-test)
            exercise-confidential-client-auth-code-flow-test
        ;;
        exercise-using-tokens-deploy)
	    exercise-using-tokens-deploy
	;;
        exercise-using-tokens-undeploy)
	    exercise-using-tokens-undeploy
	;;
        exercise-using-tokens-test)
	    exercise-using-tokens-test
	;;
        exercise-protecting-apis-deploy)
	    exercise-protecting-apis-deploy
	;;
        exercise-protecting-apis-undeploy)
	    exercise-protecting-apis-undeploy
	;;
        exercise-csrf-attacks-deploy)
            exercise-csrf-attacks-deploy
        ;;
        exercise-csrf-attacks-undeploy)
            exercise-csrf-attacks-undeploy
        ;;
        exercise-csrf-attacks-test)
            exercise-csrf-attacks-test
        ;;
        exercise-protecting-apis-test)
	    exercise-protecting-apis-test
	;;
        exercise-oidc-in-spas-deploy)
	    exercise-oidc-in-spas-deploy
	;;
        exercise-oidc-in-spas-undeploy)
	    exercise-oidc-in-spas-undeploy
	;;
        exercise-oidc-in-spas-test)
	    exercise-oidc-in-spas-test
	;;
        test-all)
	    test-all
	;;
    esac
    shift
done

if [ $ERRORS -eq 0 ]; then
    echo "Success - no errors detected ($SUCCESSES successes)"
else
    echo "*** Failed - $ERRORS error(s) found ($SUCCESSES successes)"
fi
