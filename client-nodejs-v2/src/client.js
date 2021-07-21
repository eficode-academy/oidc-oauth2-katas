const os = require("os");
const path = require('path');
const express = require('express');
const session = require('express-session');
const redis = require('redis')
const passport = require('passport');
const bodyParser = require('body-parser');
const logger = require('morgan');
const { Issuer, Strategy } = require('openid-client');
const randomstring = require('randomstring');

const client_title = process.env.CLIENT_TITLE || 'Confidential Client';
const client_stylefile = process.env.CLIENT_STYLEFILE || 'style.css';
const port = process.env.CLIENT_PORT || 5000;
const base_url = process.env.CLIENT_BASE_URL || 'http://localhost:' + port
const client_id = process.env.CLIENT_ID;
const client_secret = process.env.CLIENT_SECRET;
const oidc_issuer_url = process.env.OIDC_ISSUER_URL;
const redis_url = process.env.REDIS_URL;
const session_secret = process.env.SESSION_SECRET || randomstring.generate(32);
const hostname = os.hostname();

console.log('CLIENT_BASE_URL', base_url);
console.log('CLIENT_ID', client_id);
console.log('CLIENT_SECRET', client_secret);
console.log('OIDC_ISSUER_URL', oidc_issuer_url);
console.log('REDIS_URL', redis_url);

const app = express();
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'ejs');

app.use(logger('combined'));
app.use(express.static('src/static'));
const session_config = { secret: session_secret,
			 resave: false,
			 saveUninitialized: false };
if (app.get('env') === 'production') {
  app.set('trust proxy', 1)
  session_config.cookie.secure = true
}
if (redis_url) {
    console.log('Using Redis session store');
    const RedisStore = require('connect-redis')(session)
    const redisClient = redis.createClient({ url: redis_url });
    redisClient.on('connect', () => { console.log('Redis connected'); });
    redisClient.on('error', (err) => { console.log('Redis error', err); });
    redisClient.on('reconnecting', () => { console.log('Redis reconnecting'); });
    session_config.store = new RedisStore({ client: redisClient,
					    ttl: 60*60*12  // Seconds
					  });
} else {
    console.log('Using Memory session store');
}
app.use(session(session_config));
app.use(bodyParser.urlencoded({ extended: true }));
app.use(express.json());
app.use(passport.initialize());
app.use(passport.session());

// Middleware to check if user is logged in
function isLoggedIn(req, res, next) {
    console.log('Check login of user', req.user);
    if ( ! req.user) {
        console.log('User not logged in');
        return res.redirect('/');
    }
    next();
}

// Serve login page
app.get('/', (req, res) => {
    now = new Date(Date.now());
    res.render('index', {'client_title': client_title,
                         'client_title2': ' ('+hostname+' @ '+now.toISOString()+')',
                         'client_stylefile': client_stylefile,
                         'client_id': client_id,
                         'oidc_issuer_url': oidc_issuer_url});
});

Issuer.discover(oidc_issuer_url)
    .then(function (issuer) {
        console.log('Discovered issuer %s %O', issuer.issuer, issuer.metadata);

        // Client settings for authorization code flow
        var client = new issuer.Client({
            client_id: client_id,
            client_secret: client_secret,
            usePKCE: false,
            redirect_uris: [base_url+'/callback'],
            response_types: ['code'],
            token_endpoint_auth_method: 'client_secret_post'
        });

        // Validation strategy
        passport.use('oidc',
                     new Strategy({ client }, (tokenSet, userinfo, done) => {
                         // 'user' is a composite object with userinfo, tokens and claims
                         return done(null, {userinfo: userinfo, claims: tokenSet.claims(), tokenSet: tokenSet});
                     })
                    );

        passport.serializeUser(function(user, done) {
            done(null, user);
        });
        passport.deserializeUser(function(user, done) {
            done(null, user);
        });

        // Initiate authorization code flow using the 'oidc' strategy with customized scope
        app.post('/login', (req, res, next) => {
            scope = req.body.scope;
            console.log('Requesting scope', scope);
            passport.authenticate('oidc', { scope: scope })(req, res, next);
        });

        // Authorization code flow callback
        app.get('/callback', (req, res, next) => {
            passport.authenticate('oidc', {
                successRedirect: '/user',
                failureRedirect: '/'
            })(req, res, next);
        });

        // End session and redirect to login page
        app.post('/logout', (req, res) => {
            req.session.destroy((err) => {
                res.redirect(client.endSessionUrl({ id_token_hint: req.user.tokenSet.id_token,
                                                    post_logout_redirect_uri: base_url}));
            });
        });

        // This actions checks login through a normal authorization code flow but with `prompt=none`
        app.post('/refresh', (req, res) => {
            client.refresh(req.user.tokenSet.refresh_token).then((tokenSet) => {
                console.log('new tokens', tokenSet);
                req.user.tokenSet = tokenSet;
                res.redirect('/user');
            });
        });

        // Show 'secret' information like tokens. Only shown to logged-in users
        app.get('/user', isLoggedIn, (req, res) => {
            now = new Date(Date.now());
            console.log('User data', req.user);
            res.render('token', {'client_title': client_title,
                                 'client_title2': ' ('+hostname+' @ '+now.toISOString()+')',
                                 'client_stylefile': client_stylefile,
                                 'username': req.user.userinfo.preferred_username,
                                 'id_token': req.user.tokenSet.id_token,
                                 'id_token_claims': JSON.stringify(req.user.claims, null, '  '),
                                 'access_token':  req.user.tokenSet.access_token,
                                 'refresh_token':  req.user.tokenSet.refresh_token
                                });
            // setInterval(function () {
            //  console.log('Check id token is still valid using introspection...');
            //  client.introspect(req.user.tokenSet.id_token).then(function (token_status) {
            //      console.log('Token introspect result', token_status);
            //      if ( ! token_status.active ) {
            //          console.log('Id token no longer active');
            //      }
            //  })
            // }, 5000);
        });

        // Error handler
        app.use(function(err, req, res, next) {
            console.error('Error handler', err);
	    res.status(err.status || 500);
	    if (req.app.get('env') === 'development') {
		res.end(err.message);
	    } else {
		res.end('Error!');
	    }
        });
    });

app.listen(port, () => {
    console.log(`Client listening on port ${port}!`);
});
