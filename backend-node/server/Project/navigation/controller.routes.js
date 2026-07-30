'use strict';

const crypto = require('crypto');
const express = require('express');
const config = require('./config/navigation.config');
const controller = require('./service/controller-observation.service');
const router = express.Router();

function safeEqual(actual, expected) {
  const left = Buffer.from(String(actual || ''));
  const right = Buffer.from(String(expected || ''));
  return left.length === right.length && crypto.timingSafeEqual(left, right);
}

function authenticate(request, response, next) {
  if (!config.controllerApiKey) {
    return response.status(503).json({
      error: {
        code: 'CONTROLLER_NOT_CONFIGURED',
        message: 'Controller ingestion is not configured'
      }
    });
  }
  if (!safeEqual(request.get('x-controller-api-key'), config.controllerApiKey)) {
    return response.status(401).json({
      error: { code: 'INVALID_CONTROLLER_KEY', message: 'Controller API key is invalid' }
    });
  }
  return next();
}

router.post('/observations', authenticate, async function (request, response) {
  try {
    const result = await controller.ingest(request.body || {});
    return response.status(result.duplicate ? 200 : 202).json({
      code: 20000,
      message: 'Success',
      data: result
    });
  } catch (cause) {
    return response.status(cause.status || 500).json({
      error: {
        code: cause.code || 'CONTROLLER_INGESTION_ERROR',
        message: cause.message || 'Controller observation failed'
      }
    });
  }
});

module.exports = router;
