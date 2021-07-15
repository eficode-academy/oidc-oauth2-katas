const fs = require('fs');
const express = require('express');
const session = require('express-session');
const passport = require('passport');
//const flash = require('connect-flash');
const ensureLoggedIn = require('connect-ensure-login').ensureLoggedIn;
const bodyParser = require('body-parser');
const cookieParser = require('cookie-parser');
const logger = require('morgan');
const mustache = require('mustache');
const { Issuer, Strategy } = require('openid-client');

const client_title = process.env.CLIENT_TITLE || 'Confidential Client';
const client_stylefile = process.env.CLIENT_STYLEFILE || 'style.css';
const port = process.env.CLIENT_PORT || 5000;
const base_url = process.env.CLIENT_BASE_URL || 'http://localhost:' + port
const app = express();

const template_index = fs.readFileSync('src/views/index.html', 'utf-8');
const template_token = fs.readFileSync('src/views/token.html', 'utf-8');

const client_id = process.env.CLIENT_ID;
const client_secret = process.env.CLIENT_SECRET;
const oidc_issuer_url = process.env.OIDC_ISSUER_URL;

console.log('CLIENT_BASE_URL', base_url);
console.log('CLIENT_ID', client_id);
console.log('CLIENT_SECRET', client_secret);
console.log('OIDC_ISSUER_URL', oidc_issuer_url);

app.use(logger('combined'));
app.use(express.static('src/static'));
app.use(session({ secret: "mySessionSecret" }));
app.use(bodyParser.urlencoded({ extended: true }));
app.use(cookieParser());
app.use(express.json());
app.use(passport.initialize());
app.use(passport.session());
//app.use(flash());

// Serve login page
app.get('/', (req, res) => {
    res.send(mustache.render(template_index, {'client_title': client_title,
					      'client_stylefile': client_stylefile,
					      'client_id': client_id,
					      'oidc_issuer_url': oidc_issuer_url}));
});

// Show 'secret' information like tokens. Only shown to logged-in users
app.get('/user/', ensureLoggedIn('/'), (req, res) => {
    console.log('xxx user', req.user);
    res.send(mustache.render(template_token, {'client_title': client_title,
					      'client_stylefile': client_stylefile,
					      'username': req.user.userinfo.preferred_username,
					      'id_token': req.user.tokenSet.id_token,
					      'id_token_claims': JSON.stringify(req.user.claims, null, '  '),
					      'access_token':  req.user.tokenSet.access_token,
					      'refresh_token':  req.user.tokenSet.refresh_token
					     }));
});

Issuer.discover(oidc_issuer_url)
    .then(function (issuer) {
	console.log('Discovered issuer %s %O', issuer.issuer, issuer.metadata);

	var client = new issuer.Client({
	    client_id: client_id,
	    client_secret: client_secret,
	    usePKCE: false,
	    redirect_uris: [base_url+'/callback'],
	    response_types: ['code'],
	    token_endpoint_auth_method: 'client_secret_post'
	});
	
	passport.use('oidc',
		     new Strategy({ client }, (tokenSet, userinfo, done) => {
			 console.log('yyy', userinfo);
			 return done(null, {userinfo: userinfo, claims: tokenSet.claims(), tokenSet: tokenSet});
		     })
		    );

	passport.serializeUser(function(user, done) {
	    done(null, user);
	});
	passport.deserializeUser(function(user, done) {
	    done(null, user);
	});

	app.post('/login', (req, res, next) => {
	    scope = req.body.scope;
	    console.log('Requesting scope', scope);
	    passport.authenticate('oidc', { scope: scope })(req, res, next);
	});

	app.get('/callback', (req, res, next) => {
	    passport.authenticate('oidc', {
		successRedirect: '/user',
		failureRedirect: '/error'
	    })(req, res, next);
	});
    });

app.listen(port, () => {
    console.log(`Client listening on port ${port}!`);
});
