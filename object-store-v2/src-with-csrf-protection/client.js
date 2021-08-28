const os = require("os");
const path = require('path');
const express = require('express');
const bodyParser = require('body-parser');
const logger = require('morgan');
const uuid = require('uuid');

const client_title = process.env.CLIENT_TITLE || 'Object Store v2';
const client_stylefile = process.env.CLIENT_STYLEFILE || 'style.css';
const port = process.env.CLIENT_PORT || 5000;

const app = express();
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'ejs');

app.use(logger('combined'));
app.use(express.static('src/static'));

app.use(bodyParser.urlencoded({ extended: true }));
app.use(express.json());

const objects = {};

objects[uuid.v4()] = {title: 'Test object'}

// This is a too simplistic approach, however, it illustrates how
// forms are modified to contains a CSRF nonce that proves the source
// of the POST operation recevied the form from a valid client.
// Real nonce's should be unguessable, i.e. be dynamically created.
const csrf_nonce = 'per-request-dynamic-hash';

// Serve front page
app.get('/', (req, res) => {
    console.log('Headers in request:', req.headers)
    const username = req.headers['x-forwarded-preferred-username']
    res.render('index', {client_title,
			 client_stylefile,
			 username,
			 csrf: csrf_nonce,
			 objects});
});

app.post('/object', (req, res) => {
    console.log('bb', req.body);
    csrf = req.body['csrf-nonce'];
    if (csrf != csrf_nonce) {
	console.warn('Got CSRF nonce', csrf, 'expected', csrf_nonce);
    } else {
	const id = uuid.v4();
	objects[id] = req.body.content;
	console.log("Created object ", id, ", content '"+objects[id]+"'");
    }
    res.redirect('/');
});

app.listen(port, () => {
    console.log(`Object store listening on port ${port}!`);
});
