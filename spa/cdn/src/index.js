const express = require('express');
const serveStatic = require('serve-static');
const logger = require('morgan');

const port = process.env.CLIENT_PORT || 5000;
const dist = process.env.STATIC_FILES_PATH;
const csp_connect_sources = process.env.CSP_CONNECT_SOURCES || 'none'
const csp_script_sources = process.env.CSP_SCRIPT_SOURCES || 'none'

console.log('CSP_CONNECT_SOURCES', csp_connect_sources);
console.log('CSP_SCRIPT_SOURCES', csp_script_sources);

const app = express();
app.use(logger('combined'));

app.use((req, res, next) => {
    // See https://infosec.mozilla.org/guidelines/web_security
    let policy = "default-src 'none';";
    policy += " connect-src 'self' " + csp_connect_sources + ";";
    policy += " script-src 'self' " + csp_script_sources + ";";
    policy += " style-src 'self';";
    res.setHeader('content-security-policy', policy);
    next();
});

config = null;
if (app.get('env') != 'production') {
    config = {
        maxAge: '0'  // Don't cache data
    }
}
app.use(serveStatic(dist, config));

app.listen(port, () => {
    console.log(`Pseudo-CDN listening on port ${port}, supplying files from ${dist}`);
});
