const os = require("os");
const path = require('path');
const express = require('express');
const bodyParser = require('body-parser');
const logger = require('morgan');
const uuid = require('uuid');

const client_title = process.env.CLIENT_TITLE || 'Hazard Service';
const client_stylefile = process.env.CLIENT_STYLEFILE || 'style.css';
const port = process.env.CLIENT_PORT || 5000;
const legit_client_url = process.env.LEGIT_CLIENT_URL;

const app = express();
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'ejs');

app.use(logger('combined'));
app.use(express.static('src/static'));

app.use(bodyParser.urlencoded({ extended: true }));
app.use(express.json());

// Serve front page
app.get('/', (req, res) => {
    res.render('index', {client_title,
			 client_stylefile,
			 legit_client_url: legit_client_url});
});

app.get('/roguelink', (req, res) => {
    now = new Date(Date.now());
    res.render('roguelink', {client_title,
			     client_stylefile,
			     legit_client_url: legit_client_url});
});

app.get('/roguepost', (req, res) => {
    now = new Date(Date.now());
    res.render('roguepost', {client_title,
			     client_stylefile,
			     legit_client_url: legit_client_url,
			     object_content: 'R0u93 C0n73n7 created at '+now.toISOString()});
});

app.listen(port, () => {
    console.log(`Hazard service listening on port ${port}!`);
});
