const fs = require('fs');
const path = require('path');
const express = require('express');
const bodyParser = require('body-parser');
const logger = require('morgan');
const crypto = require('crypto');
const randomstring = require("randomstring");
const querystring = require("querystring");
const https = require('https');
const jwt_decode = require('jwt-decode');

const client_title = process.env.CLIENT_TITLE || 'Confidential Client';
const client_stylefile = process.env.CLIENT_STYLEFILE || 'style.css';
const port = process.env.CLIENT_PORT || 5000;
const base_url = process.env.CLIENT_BASE_URL || 'http://localhost:' + port

const app = express();
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'ejs');

var scope, state, nonce;
var id_token, accesS_token, refresh_token;
var id_token_claims;

const client_id = process.env.CLIENT_ID;
const client_secret = process.env.CLIENT_SECRET;
const oidc_auth_url = process.env.OIDC_AUTH_URL;
const oidc_token_url = process.env.OIDC_TOKEN_URL;

console.log('CLIENT_BASE_URL', base_url)
console.log('CLIENT_ID', client_id)
console.log('CLIENT_SECRET', client_secret)
console.log('OIDC_AUTH_URL', oidc_auth_url)
console.log('OIDC_TOKEN_URL', oidc_token_url)

app.use(logger('combined'));
app.use(bodyParser.urlencoded({ extended: true }));
app.use(express.json());
app.use(express.static('src/static'));

// Serve login page, unless we already have id information cached - in which case we
// redirect to the 'already logged-in' area
app.get('/', (req, res) => {
    if (id_token_claims) {
        return res.redirect(base_url+'/protected');
    }
    res.render('index', {'client_title': client_title,
                         'client_title2': '',
                         'client_stylefile': client_stylefile,
                         'client_id': client_id,
                         'oidc_auth_url': oidc_auth_url});
});

// Show 'secret' information like tokens. This client is not secure and stores login-state
// globally, so this is only for  demonstration purposes
app.get('/protected/', (req, res) => {
    res.render('token', {'client_title': client_title,
                         'client_title2': '',
                         'client_stylefile': client_stylefile,
                         'username': id_token_claims.preferred_username,
                         'id_token': id_token,
                         'id_token_claims': JSON.stringify(id_token_claims, null, '  '),
                         'access_token': access_token,
                         'refresh_token': refresh_token });
});

// First step in an authorization code flow login. Redirect to Identity provider (IdP).
app.post('/login', (req, res) => {
    scope = req.body.scope;
    state = Buffer.from(randomstring.generate(24)).toString('base64');
    nonce = Buffer.from(randomstring.generate(24)).toString('base64');
    console.log('Using scope', scope, 'state', state, 'nonce', nonce);

    let url = oidc_auth_url + '?' + querystring.encode({
        'response_type': 'code',               // Use authorization code flow
        'client_id': client_id,                // This is who we are
        'scope': scope,                        // What we 'want'
        'redirect_uri': base_url+'/callback',  // Call us here when login done at IdP
        'state': state,                        // For our own use, if we need it and for protection
        'nonce': nonce                         // Replay protection, echoed in id_token
    });
    console.log('Redirecting login to identity provider', url);
    res.redirect(url);
});

// Second step, we get a callback from the IdP after a successful login.
// We get a one-time code we can exchange for tokens.
app.get('/callback', (req, res) => {
    console.log('GET', req.originalUrl)
    let code = req.query.code
    let idp_state = req.query.state
    console.log('Callback with code', code, 'state', idp_state, 'our state is', state);

    if ( ! code) {
        error = req.query.error;
        console.log('No code returned. Error', error);
        id_token = null;
        id_token_claims = null;
        access_token = null;
        refresh_token = null;
        return res.redirect(base_url);
    }

    if (state != idp_state) {
        console.log('Error, state mismatch. We do not know this callback.');
        return res.redirect(base_url);
    }

    // This is a confidential client - authorize towards IdP with client id and secret
    const client_creds = 'Basic ' + Buffer.from(querystring.escape(client_id)+':'+querystring.escape(client_secret), 'ascii').toString('base64')
    const data = querystring.encode({
        'code': code,
        'grant_type': 'authorization_code',
        'redirect_uri': base_url+'/callback'});
    const options = {
        method: 'POST',
        headers: {
            'Authorization': client_creds,
            'Content-Type': 'application/x-www-form-urlencoded',
            'Content-Length': data.length
        }
    };

    // Exchange code for tokens using the token endpoint
    const post = https.request(oidc_token_url, options, (post_resp) => {
        console.log('statusCode:', post_resp.statusCode);
        post_resp.on('data', (data) => {
            const token_data = JSON.parse(data);
            console.log('Token response', token_data);
            if (post_resp.statusCode == 200){
                if (token_data.id_token) {
                    id_token =  token_data.id_token;
                    console.log('ID token', id_token);

                    // TODO: Validate signature on id_token

                    id_token_claims = jwt_decode(id_token);
                    console.log('ID token claims', id_token_claims);
                }
                if (token_data.access_token) {
                    access_token = token_data.access_token
                    console.log('Access token', access_token);
                }               
                if (token_data.refresh_token) {
                    refresh_token = token_data.refresh_token
                    console.log('Refresh token', refresh_token);
                }               
                res.redirect(base_url);
            }
        });
    });
    post.write(data);
    post.end();
});

app.post('/logout', (req, res) => {
    // Very basic logout, clear local state
    id_token = null;
    id_token_claims = null;
    access_token = null;
    refresh_token = null;
    res.redirect(base_url);
});

// This actions checks login through a normal authorization code flow but with `prompt=none`
app.post('/checklogin', (req, res) => {
    state = Buffer.from(randomstring.generate(24)).toString('base64');
    nonce = Buffer.from(randomstring.generate(24)).toString('base64');
    console.log('Using scope', scope, 'state', state, 'nonce', nonce);

    let url = oidc_auth_url + '?' + querystring.encode({
        'response_type': 'code',               // Use authorization code flow
        'client_id': client_id,                // This is who we are
        'scope': scope,                        // What we 'want'
        'redirect_uri': base_url+'/callback',  // Call us here when login done at IdP
        'state': state,                        // For our own use, if we need it and for protection
        'nonce': nonce,                        // Replay protection, echoed in id_token
        'id_token_hint': id_token,             // Check login for this identity
        'prompt': 'none'                       // Don't query user for username/password
    });
    console.log('Redirecting login to identity provider', url);
    res.redirect(url);
});

app.listen(port, () => {
    console.log(`Client listening on port ${port}!`);
});
