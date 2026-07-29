'use strict';

const express = require('express');
const admin = require('./service/map-admin.service');
const { requireAdmin } = require('../mobile-auth/mobile-auth.middleware');
const router = express.Router();

function ok(response, data, status) {
  return response.status(status || 200).json({ code: 20000, message: 'Success', data });
}

function fail(response, cause) {
  return response.status(cause.status || 500).json({
    error: {
      code: cause.code || 'MAP_ADMIN_ERROR',
      message: cause.message || 'Map administration request failed'
    }
  });
}

router.use(requireAdmin);

router.get('/:resource', async function (request, response) {
  try {
    return ok(response, {
      items: await admin.list(request.params.resource, request.query.include_inactive === 'true')
    });
  } catch (cause) {
    return fail(response, cause);
  }
});

router.get('/:resource/:id', async function (request, response) {
  try {
    return ok(response, await admin.get(request.params.resource, request.params.id));
  } catch (cause) {
    return fail(response, cause);
  }
});

router.post('/:resource', async function (request, response) {
  try {
    return ok(response, await admin.create(request.params.resource, request.body || {}), 201);
  } catch (cause) {
    return fail(response, cause);
  }
});

router.patch('/:resource/:id', async function (request, response) {
  try {
    return ok(response, await admin.update(
      request.params.resource,
      request.params.id,
      request.body || {}
    ));
  } catch (cause) {
    return fail(response, cause);
  }
});

router.delete('/:resource/:id', async function (request, response) {
  try {
    return ok(response, await admin.deactivate(request.params.resource, request.params.id));
  } catch (cause) {
    return fail(response, cause);
  }
});

module.exports = router;
