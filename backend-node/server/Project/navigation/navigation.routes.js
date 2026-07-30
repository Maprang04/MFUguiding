'use strict';

const express = require('express');
const router = express.Router();
const navigation = require('./service/navigation-session.service');
const config = require('./config/navigation.config');
const simulatorScenarios = require('./simulator/scenarios');
const mapAdminRoutes = require('./map-admin.routes');
const controllerRoutes = require('./controller.routes');

function clientId(request) {
  return String(
    request.get('x-navigation-client-id') ||
    (request.body && request.body.client_id) ||
    (request.query && request.query.client_id) ||
    ''
  ).trim();
}

function ok(response, data, status) {
  return response.status(status || 200).json({ code: 20000, message: 'Success', data });
}

function fail(response, error) {
  const status = error && error.status ? error.status : 500;
  return response.status(status).json({
    error: {
      code: error && error.code ? error.code : 'NAVIGATION_ERROR',
      message: error && error.message ? error.message : 'Navigation request failed',
      request_id: response.getHeader('x-request-id') || null
    }
  });
}

router.use('/admin', mapAdminRoutes);
router.use('/controller', controllerRoutes);

router.get('/health', async function (_request, response) {
  try {
    const result = await navigation.health();
    return ok(response, result, result.status === 'ok' ? 200 : 503);
  } catch (error) {
    return fail(response, error);
  }
});

router.get('/destinations', async function (_request, response) {
  try {
    return ok(response, { items: await navigation.destinations() });
  } catch (error) {
    return fail(response, error);
  }
});

router.get('/destinations/:destinationId', async function (request, response) {
  try {
    const item = await navigation.destination(request.params.destinationId);
    if (!item) return fail(response, Object.assign(new Error('Destination does not exist'), {
      status: 404,
      code: 'DESTINATION_NOT_FOUND'
    }));
    return ok(response, item);
  } catch (error) {
    return fail(response, error);
  }
});

router.get('/access-points', async function (_request, response) {
  try {
    return ok(response, { items: await navigation.accessPoints() });
  } catch (error) {
    return fail(response, error);
  }
});

router.get('/map-config', async function (_request, response) {
  try {
    return ok(response, await navigation.mapConfig());
  } catch (error) {
    return fail(response, error);
  }
});

router.post('/sessions', async function (request, response) {
  try {
    return ok(response, await navigation.createSession(request.body || {}), 201);
  } catch (error) {
    return fail(response, error);
  }
});

router.get('/sessions/:sessionId', async function (request, response) {
  try {
    return ok(response, await navigation.getSession(request.params.sessionId, clientId(request)));
  } catch (error) {
    return fail(response, error);
  }
});

router.patch('/sessions/:sessionId/destination', async function (request, response) {
  try {
    return ok(response, await navigation.changeDestination(
      request.params.sessionId,
      request.body && request.body.destination_id,
      clientId(request)
    ));
  } catch (error) {
    return fail(response, error);
  }
});

router.post('/sessions/:sessionId/refresh', async function (request, response) {
  try {
    return ok(response, await navigation.getSession(request.params.sessionId, clientId(request)));
  } catch (error) {
    return fail(response, error);
  }
});

router.post('/sessions/:sessionId/complete', async function (request, response) {
  try {
    return ok(response, await navigation.completeSession(
      request.params.sessionId,
      clientId(request),
      'completed'
    ));
  } catch (error) {
    return fail(response, error);
  }
});

router.delete('/sessions/:sessionId', async function (request, response) {
  try {
    return ok(response, await navigation.completeSession(
      request.params.sessionId,
      clientId(request),
      'cancelled'
    ));
  } catch (error) {
    return fail(response, error);
  }
});

router.get('/sessions/:sessionId/observations', async function (request, response) {
  try {
    const items = await navigation.listObservations(
      request.params.sessionId,
      clientId(request),
      request.query.limit
    );
    return ok(response, { items, next_cursor: null });
  } catch (error) {
    return fail(response, error);
  }
});

router.post('/simulator/observations', async function (request, response) {
  if (!config.simulatorEnabled) {
    return fail(response, Object.assign(new Error('Simulator is disabled'), {
      status: 404,
      code: 'SIMULATOR_DISABLED'
    }));
  }
  try {
    return ok(response, await navigation.submitObservation(
      Object.assign({}, request.body || {}, { source: 'simulator' })
    ), 202);
  } catch (error) {
    return fail(response, error);
  }
});

router.post('/simulator/scenarios/:scenarioId/run', async function (request, response) {
  if (!config.simulatorEnabled) {
    return fail(response, Object.assign(new Error('Simulator is disabled'), {
      status: 404,
      code: 'SIMULATOR_DISABLED'
    }));
  }
  const scenario = simulatorScenarios[request.params.scenarioId];
  if (!scenario) {
    return fail(response, Object.assign(new Error('Simulator scenario does not exist'), {
      status: 404,
      code: 'SCENARIO_NOT_FOUND'
    }));
  }
  const clientId = request.body && request.body.client_id;
  if (!clientId) {
    return fail(response, Object.assign(new Error('client_id is required'), {
      status: 400,
      code: 'INVALID_REQUEST'
    }));
  }
  try {
    const results = [];
    for (const step of scenario) {
      results.push(await navigation.submitObservation({
        client_id: clientId,
        associated_ap: step.associated_ap,
        rssi: step.rssi,
        timestamp: new Date().toISOString(),
        source: 'simulator'
      }));
    }
    return ok(response, {
      scenario_id: request.params.scenarioId,
      steps_processed: results.length,
      final_state: results.length ? results[results.length - 1].session : null
    }, 202);
  } catch (error) {
    return fail(response, error);
  }
});

module.exports = router;
