'use strict';

// node:test, not jest — the fixture must not need a registry to prove the archetype's test step.

const test = require('node:test');
const assert = require('node:assert');
const { handler } = require('./index.js');

function call(url) {
  const res = {
    statusCode: null,
    headers: null,
    body: '',
    writeHead(code, headers) {
      this.statusCode = code;
      this.headers = headers;
    },
    end(chunk) {
      this.body = chunk;
    },
  };
  handler({ url }, res);
  return res;
}

test('GET /health answers ok', () => {
  const res = call('/health');
  assert.equal(res.statusCode, 200);
  assert.equal(JSON.parse(res.body).status, 'ok');
});

test('an unknown path is a 404', () => {
  const res = call('/nope');
  assert.equal(res.statusCode, 404);
});
