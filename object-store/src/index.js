const express = require('express');
const logger = require('morgan');
const jwksRsa = require('jwks-rsa');
var jwt = require('express-jwt');
const uuid = require('uuid');
const { Issuer } = require('openid-client');

const port = process.env.CLIENT_PORT || 5010;
const oidc_issuer_url = process.env.OIDC_ISSUER_URL;

const app = express();

const objects = {};

objects[uuid.v4()] = {title: 'Test object'}

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
	    // Here we could check more 'static' properties
	    // audience: ...
	    // issuer: ...
	}));

	app.get('/objects', (req, res) => {
	    res.send(Object.keys(objects));
	});

	// See also npm module 'express-jwt-authz'
	function allowScopes(wants) {
	    return function(req, res, next) {
		console.log('Have auth.scope', req.auth.scope.split(" "), 'wants', wants);
		const have = req.auth.scope.split(" ");
		for (const idx in wants) {
		    if ( ! have.includes(wants[idx])) {
			console.log('Missing scope', wants[idx]);
			const err = new Error();
			err.message = 'insufficient_scope'
			err.status = 403;
			next(err);
		    }
		}
		next();
	    }
	}

	app.post('/object',
		 //allowScopes(['xxx']),
		 (req, res) => {
		     const id = uuid.v4();
		     objects[id] = req.body;
		     res.send(id);
	});

	app.get('/object/:id',
		//allowScopes(['yyy']),
		(req, res) => {
		    const id = req.params.id;
		    res.send(objects[id]);
		});

	app.use(function (err, req, res, next) {
	    console.log('Error handler', err);
	    if (err.name === 'UnauthorizedError') {
		res.status(401).send('invalid token');
	    } else {
		res.status(err.status).send(err);
	    }
	});

	app.listen(port, () => {
	    console.log(`Object store listening on port ${port}!`);
	});
    });
