'use strict';

// Minimal HTTP app for the node-service selftest: no dependencies, so `npm ci` has nothing to
// fetch and the only thing under test is the archetype.

const http = require('node:http');

const PORT = Number(process.env.PORT || 8080);

function handler(req, res) {
  if (req.url === '/health') {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', service: process.env.SELFTEST_SERVICE || 'node-app-fixture' }));
    return;
  }
  res.writeHead(404, { 'content-type': 'application/json' });
  res.end(JSON.stringify({ error: 'not found' }));
}

if (require.main === module) {
  http.createServer(handler).listen(PORT, () => {
    console.log(`listening on ${PORT}`);
  });
}

module.exports = { handler };
