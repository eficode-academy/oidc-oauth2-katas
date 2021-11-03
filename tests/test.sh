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

function exercise-authorization-code-flow-setup-env {
    authorization-code-flow.md-prerequisites-block1
    authorization-code-flow.md-exercise-block3
    authorization-code-flow.md-exercise-block5
}

function exercise-authorization-code-flow-deploy {
    authorization-code-flow.md-prerequisites-block1
    authorization-code-flow.md-exercise-block1
    authorization-code-flow.md-exercise-block2
    authorization-code-flow.md-exercise-block3
    authorization-code-flow.md-exercise-block4
    authorization-code-flow.md-exercise-block5
    authorization-code-flow.md-exercise-block6
    authorization-code-flow.md-exercise-block7

    kubectl wait --for=condition=ready pod -l app=client1 --timeout=60s
    sleep 10
}

function exercise-authorization-code-flow-undeploy {
    authorization-code-flow.md-clean-up-block1
    kubectl wait --for=delete pod -l app=client1 --timeout=120s || true
}

function exercise-authorization-code-flow-test {
    exercise-authorization-code-flow-setup-env
    HTTP_STATUS=$(curl -s $CLIENT1_BASE_URL -o /dev/null -w '%{http_code}')
    if [ "$HTTP_STATUS" != '200' ]; then
        echo "*** Error, got HTTP status $HTTP_STATUS"
        let ERRORS+=1
    else
        let SUCCESSES+=1
    fi
}


# This exercise extends 'authorization-code-flow'
function exercise-authorization-code-flow2-setup-env {
    exercise-authorization-code-flow-setup-env
    authorization-code-flow2.md-single-sign-on-sso-block1
}

function exercise-authorization-code-flow2-deploy {
    exercise-authorization-code-flow2-setup-env

    exercise-authorization-code-flow-deploy
    authorization-code-flow2.md-prerequisites-block1
    authorization-code-flow2.md-logout-block1
    #authorization-code-flow2.md-identity-provider-session-cookies-block1
    authorization-code-flow2.md-single-sign-on-sso-block1
    authorization-code-flow2.md-single-sign-on-sso-block2
    authorization-code-flow2.md-single-sign-on-sso-block3

    kubectl wait --for=condition=ready pod -l app=client2 --timeout=60s
    sleep 10
}

function exercise-authorization-code-flow2-undeploy {
    authorization-code-flow2.md-clean-up-block1
    kubectl wait --for=delete pod -l app=client2 --timeout=120s || true
}

function exercise-authorization-code-flow2-test {
    exercise-authorization-code-flow2-setup-env

    exercise-authorization-code-flow-test

    HTTP_STATUS=$(curl -s $CLIENT2_BASE_URL -o /dev/null -w '%{http_code}')
    if [ "$HTTP_STATUS" != '200' ]; then
        echo "*** Error, got HTTP status $HTTP_STATUS"
        let ERRORS+=1
    else
        let SUCCESSES+=1
    fi
}


function exercise-using-tokens-setup-env {
    using-tokens.md-deploy-client-block1
    using-tokens.md-using-tokens-with-curl-block2
    using-tokens.md-introspecting-tokens-block1
    using-tokens.md-refreshing-tokens-block1
    using-tokens.md-client-side-logout-block1
}

function exercise-using-tokens-deploy {
    exercise-using-tokens-setup-env

    using-tokens.md-prerequisites-block1
    using-tokens.md-deploy-client-block1
    using-tokens.md-deploy-client-block2
    using-tokens.md-deploy-client-block3

    kubectl wait --for=condition=ready pod -l app=client1 --timeout=60s
    sleep 10
}

function exercise-using-tokens-undeploy {
    using-tokens.md-clean-up-block1
    kubectl wait --for=delete pod -l app=client1 --timeout=120s || true
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

    # Commands that setup actions which we cannot test without access to tokens.
    # However, run the commands that we can execute...
    using-tokens.md-using-tokens-with-curl-block2
    using-tokens.md-introspecting-tokens-block1
    using-tokens.md-refreshing-tokens-block1
    using-tokens.md-client-side-logout-block1
}


function exercise-protecting-apis-setup-env {
    protecting-apis.md-prerequisites-block1
    protecting-apis.md-exercise-block1
    protecting-apis.md-accessing-the-api-block2
}

function exercise-protecting-apis-deploy {
    exercise-protecting-apis-setup-env

    protecting-apis.md-deploy-client-block1
    protecting-apis.md-deploy-client-block2
    protecting-apis.md-deploy-api-block1
    protecting-apis.md-deploy-api-block2

    kubectl wait --for=condition=ready pod -l app=client1 --timeout=60s
    kubectl wait --for=condition=ready pod -l app=api --timeout=60s
    sleep 10
    protecting-apis.md-adding-scope-to-the-api-block2

    kubectl wait --for=condition=ready pod -l app=client1 --timeout=60s
    kubectl wait --for=condition=ready pod -l app=api --timeout=60s
    sleep 10
}

function exercise-protecting-apis-undeploy {
    protecting-apis.md-clean-up-block1
    kubectl wait --for=delete pod -l app=client1 --timeout=120s || true
    kubectl wait --for=delete pod -l app=api --timeout=120s || true
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


function exercise-authorizing-proxy-setup-env {
    authorizing-proxy.md-deploy-oauth2-proxy-block1
    authorizing-proxy.md-deploy-oauth2-proxy-block3
}

function exercise-authorizing-proxy-deploy {
    exercise-authorizing-proxy-setup-env

    authorizing-proxy.md-prerequisites-block1
    authorizing-proxy.md-deploy-httpbin-block1
    authorizing-proxy.md-deploy-oauth2-proxy-block2
    authorizing-proxy.md-deploy-oauth2-proxy-block4
    authorizing-proxy.md-deploy-oauth2-proxy-block5
    authorizing-proxy.md-deploy-oauth2-proxy-block6

    kubectl wait --for=condition=ready pod -l app=oauth2-proxy --timeout=60s
    kubectl wait --for=condition=ready pod -l app=httpbin --timeout=60s
    sleep 10
}

function exercise-authorizing-proxy-undeploy {
    authorizing-proxy.md-clean-up-block1
    kubectl wait --for=delete pod -l app=oauth2-proxy --timeout=120s || true
    kubectl wait --for=delete pod -l app=httpbin --timeout=120s || true
}

function exercise-authorizing-proxy-test {
    exercise-authorizing-proxy-setup-env

    HTTP_STATUS=$(curl -s $OAUTH2_PROXY_EP/objects -o /dev/null -w '%{http_code}')
    if [ "$HTTP_STATUS" != '403' ]; then
        echo "*** Error, got HTTP status $HTTP_STATUS"
        let ERRORS+=1
    else
        let SUCCESSES+=1
    fi
}


function exercise-csrf-attacks-setup-env {
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
    kubectl wait --for=delete pod -l app=oauth2-proxy --timeout=120s || true
    kubectl wait --for=delete pod -l app=object-store-v2 --timeout=120s || true
    kubectl wait --for=delete pod -l app=hazard --timeout=120s || true
}

function exercise-csrf-attacks-test {
    exercise-csrf-attacks-setup-env

    HTTP_STATUS=$(curl -s $OAUTH2_PROXY_EP -o /dev/null -w '%{http_code}')
    if [ "$HTTP_STATUS" != '403' ]; then
        echo "*** Error, got HTTP status $HTTP_STATUS"
        let ERRORS+=1
    else
        let SUCCESSES+=1
    fi

    # Our test inludes the two code update schenarios
    csrf-attacks.md-protecting-the-object-store-against-csrf-block2

    HTTP_STATUS=$(curl -s $OAUTH2_PROXY_EP -o /dev/null -w '%{http_code}')
    if [ "$HTTP_STATUS" != '403' ]; then
        echo "*** Error, got HTTP status $HTTP_STATUS"
        let ERRORS+=1
    else
        let SUCCESSES+=1
    fi

    csrf-attacks.md-protecting-the-object-store-against-csrf-block3

    HTTP_STATUS=$(curl -s $OAUTH2_PROXY_EP -o /dev/null -w '%{http_code}')
    if [ "$HTTP_STATUS" != '403' ]; then
        echo "*** Error, got HTTP status $HTTP_STATUS"
        let ERRORS+=1
    else
        let SUCCESSES+=1
    fi
}


function exercise-session-storage-setup-env {
    session-storage.md-exercise-block3
}

function exercise-session-storage-deploy {
    exercise-session-storage-setup-env

    session-storage.md-sessions-are-not-shared-across-pods-block1
    session-storage.md-sessions-are-not-shared-across-pods-block2
    session-storage.md-sessions-are-not-shared-across-pods-block3
    session-storage.md-login-state-is-not-shared-across-pods-block1
    # This deletes first version
    session-storage.md-adding-shared-session-storage-block1
    session-storage.md-adding-shared-session-storage-block2
    session-storage.md-adding-shared-session-storage-block3

    # FIXME: Doesn't work with the delete above
    #kubectl wait --for=condition=ready pod -l app=client1 --timeout=60s
    kubectl wait --for=condition=ready pod -l app=session-store --timeout=60s
    sleep 10
}

function exercise-session-storage-undeploy {
    session-storage.md-clean-up-block1
    kubectl wait --for=delete pod -l app=client1 --timeout=120s || true
    kubectl wait --for=delete pod -l app=session-store --timeout=120s || true
}

function exercise-session-storage-test {
    exercise-session-storage-setup-env
    HTTP_STATUS=$(curl -s $CLIENT1_BASE_URL -o /dev/null -w '%{http_code}')
    if [ "$HTTP_STATUS" != '200' ]; then
        echo "*** Error, got HTTP status $HTTP_STATUS"
        let ERRORS+=1
    else
        let SUCCESSES+=1
    fi
}


function exercise-oidc-in-spas-setup-env {
    oidc-in-spas.md-exercise-block1
}

function exercise-oidc-in-spas-deploy {
    exercise-oidc-in-spas-setup-env

    oidc-in-spas.md-prerequisites-block1
    oidc-in-spas.md-exercise-block1
    oidc-in-spas.md-deploy-spa-cdn-block1
    oidc-in-spas.md-deploy-login-bff-block1
    oidc-in-spas.md-deploy-login-bff-block2
    oidc-in-spas.md-deploy-api-gateway-block1
    oidc-in-spas.md-deploy-api-block1
    oidc-in-spas.md-deploy-api-block2

    kubectl wait --for=condition=ready pod -l app=spa-cdn --timeout=60s
    kubectl wait --for=condition=ready pod -l app=spa-login --timeout=60s
    kubectl wait --for=condition=ready pod -l app=spa-api-gw --timeout=60s
    kubectl wait --for=condition=ready pod -l app=api --timeout=60s
    kubectl wait --for=condition=ready pod -l app=session-store --timeout=60s
    sleep 10
}

function exercise-oidc-in-spas-undeploy {
    oidc-in-spas.md-clean-up-block1
    kubectl wait --for=delete pod -l app=spa-cdn --timeout=120s || true
    kubectl wait --for=delete pod -l app=spa-login --timeout=120s || true
    kubectl wait --for=delete pod -l app=spa-api-gw --timeout=120s || true
    kubectl wait --for=delete pod -l app=api --timeout=120s || true
    kubectl wait --for=delete pod -l app=session-store --timeout=120s || true
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

    echo "### exercise-authorization-code-flow"
    exercise-authorization-code-flow-deploy
    exercise-authorization-code-flow-test
    exercise-authorization-code-flow-undeploy

    echo "### exercise-authorization-code-flow2"
    exercise-authorization-code-flow2-deploy
    exercise-authorization-code-flow2-test
    exercise-authorization-code-flow2-undeploy

    echo "### exercise-using-tokens"
    exercise-using-tokens-deploy
    exercise-using-tokens-test
    exercise-using-tokens-undeploy

    echo "### exercise-protecting-apis"
    exercise-protecting-apis-deploy
    exercise-protecting-apis-test
    exercise-protecting-apis-undeploy

    echo "### exercise-authorizing-proxy"
    exercise-authorizing-proxy-deploy
    exercise-authorizing-proxy-test
    exercise-authorizing-proxy-undeploy

    echo "### exercise-csrf-attacks"
    exercise-csrf-attacks-deploy
    exercise-csrf-attacks-test
    exercise-csrf-attacks-undeploy

    echo "### exercise-session-storage"
    exercise-session-storage-deploy
    exercise-session-storage-test
    exercise-session-storage-undeploy

    echo "### exercise-oidc-in-spas"
    exercise-oidc-in-spas-deploy
    exercise-oidc-in-spas-test
    exercise-oidc-in-spas-undeploy
}

while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        exercise-authorization-code-flow-deploy)
            exercise-authorization-code-flow-deploy
        ;;
        exercise-authorization-code-flow-undeploy)
            exercise-authorization-code-flow-undeploy
        ;;
        exercise-authorization-code-flow-test)
            exercise-authorization-code-flow-test
        ;;
        exercise-authorization-code-flow2-deploy)
            exercise-authorization-code-flow2-deploy
        ;;
        exercise-authorization-code-flow2-undeploy)
            exercise-authorization-code-flow2-undeploy
        ;;
        exercise-authorization-code-flow2-test)
            exercise-authorization-code-flow2-test
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
        exercise-protecting-apis-test)
	    exercise-protecting-apis-test
	;;
        exercise-authorizing-proxy-deploy)
	    exercise-authorizing-proxy-deploy
	;;
        exercise-authorizing-proxy-undeploy)
	    exercise-authorizing-proxy-undeploy
	;;
        exercise-authorizing-proxy-test)
	    exercise-authorizing-proxy-test
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
        exercise-session-storage-deploy)
	    exercise-session-storage-deploy
	;;
        exercise-session-storage-undeploy)
	    exercise-session-storage-undeploy
	;;
        exercise-session-storage-test)
	    exercise-session-storage-test
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
