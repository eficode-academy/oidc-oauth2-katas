const express = require('express');
const bodyParser = require('body-parser');
const logger = require('morgan');
//const jsonwebtoken = require('jsonwebtoken');
const jwksRsa = require('jwks-rsa');
var jwt = require('express-jwt');
const uuid = require('uuid');
const { Issuer } = require('openid-client');

const env = process.env.NODE_ENV || 'production';
const port = process.env.CLIENT_PORT || 5010;
const oidc_issuer_url = process.env.OIDC_ISSUER_URL;

const app = express();

const objects = {};

objects[uuid.v4()] = 'Test object'

app.use(bodyParser.urlencoded({ extended: true }));
app.use(express.json());
app.use(logger('combined'));


Issuer.discover(oidc_issuer_url)
    .then(function (issuer) {
	console.log('Discovered issuer %s %O', issuer.issuer, issuer.metadata);

	app.use(jwt({
	    secret: jwksRsa.expressJwtSecret({
		jwksUri: issuer.jwks_uri,
		cache: true,
		timeout: 3600 // Seconds
	    }),
	    algorithms: [ 'RS256' ],
	    requestProperty: 'auth'
	}));

	app.get('/objects', (req, res) => {
	    res.send(Object.keys(objects));
	});

	function allowScope(scope) {
	    return function(req, res, next) {
		console.log('Has auth.scope', req.auth.scope.split(" "), 'asked for scope', scope);
		if (req.auth.scope.split(" ").includes(scope)) next();
		else throw new Error('Insufficient scope');
	    }
	}

	app.post('/object', (req, res) => {
	    const id = uuid.v4();
	    objects[id] = req.body.object;
	    res.send(id);
	});

	app.get('/object/:id',
		//allowScope('xxx'),
		(req, res) => {
		    const id = req.params.id;
		    res.send(objects[id]);
		});

	app.use(function (err, req, res, next) {
	    if (err.name === 'UnauthorizedError') {
		res.status(401).send('invalid token');
	    }
	});

	app.listen(port, () => {
	    console.log(`Object store listening on port ${port}!`);
	});
    });
