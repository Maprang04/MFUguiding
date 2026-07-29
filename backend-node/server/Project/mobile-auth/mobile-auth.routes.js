'use strict';

const express = require('express');
const service = require('./mobile-auth.service');
const router = express.Router();

function token(request) {
  const bearer = String(request.get('authorization') || '');
  if (bearer.toLowerCase().startsWith('bearer ')) return bearer.slice(7).trim();
  return String(request.get('x-access-token') || '').trim();
}

function ok(response, data) {
  return response.json({ code: 20000, message: 'Success', data });
}

function fail(response, error) {
  return response.status(error.status || 500).json({
    error: {
      code: error.code || 'AUTH_ERROR',
      message: error.message || 'Authentication failed'
    }
  });
}

router.post('/login', async function (request, response) {
  try {
    return ok(response, await service.login(
      request.body && request.body.email,
      request.body && request.body.password
    ));
  } catch (error) {
    console.error('Mobile auth login failed:', error);
    return fail(response, error);
  }
});

router.get('/me', async function (request, response) {
  try {
    const auth = await service.authenticate(token(request));
    if (!auth) return fail(response, Object.assign(new Error('Session is invalid or expired'), {
      status: 401,
      code: 'UNAUTHORIZED'
    }));
    return ok(response, { user: auth.user });
  } catch (error) {
    return fail(response, error);
  }
});

router.post('/logout', async function (request, response) {
  try {
    return ok(response, await service.logout(token(request)));
  } catch (error) {
    return fail(response, error);
  }
});

module.exports = router;
