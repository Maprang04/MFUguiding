'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const EventEmitter = require('events');
const navigationConfig = require('../config/navigation.config');
const MockPositioningClient = require('../integrations/mock-positioning-client');
const createService = require('../service/navigation-session.service').createService;

function clone(value) {
  return value === undefined ? undefined : JSON.parse(JSON.stringify(value));
}

function memoryRepository() {
  const sessions = new Map();
  const observations = [];
  return {
    sessions,
    observations,
    async createSession(payload) {
      const now = new Date();
      const row = Object.assign({
        routeVersion: 0,
        route: [],
        createdAt: now,
        updatedAt: now
      }, payload);
      sessions.set(row.sessionId, row);
      return clone(row);
    },
    async findSession(sessionId) {
      return clone(sessions.get(sessionId) || null);
    },
    async findActiveByUserOrClient(userId, clientId) {
      return clone(Array.from(sessions.values()).find(function (session) {
        return session.status === 'active' &&
          (session.userId === userId || session.clientId === clientId);
      }) || null);
    },
    async findActiveByClient(clientId) {
      return clone(Array.from(sessions.values()).find(function (session) {
        return session.status === 'active' && session.clientId === clientId;
      }) || null);
    },
    async updateSession(sessionId, changes) {
      const current = sessions.get(sessionId);
      Object.assign(current, clone(changes), { updatedAt: new Date() });
      return clone(current);
    },
    async createObservation(payload) {
      observations.push(clone(payload));
      return clone(payload);
    },
    async listObservations(sessionId, limit) {
      return clone(observations.filter(function (row) {
        return row.sessionId === sessionId;
      }).slice(-limit).reverse());
    },
    async healthCheck() {
      return true;
    }
  };
}

function setup() {
  const repository = memoryRepository();
  const positioning = new MockPositioningClient(navigationConfig);
  const events = new EventEmitter();
  const service = createService({ repository, positioning, events });
  return { repository, positioning, events, service };
}

test('creates a navigation session and rejects a duplicate active session', async function () {
  const context = setup();
  const created = await context.service.createSession({
    client_id: 'device-1',
    destination_id: 'room_2'
  });

  assert.equal(created.status, 'active');
  assert.equal(created.client_id, 'device-1');
  assert.equal(created.destination_id, 'room_2');
  await assert.rejects(
    context.service.createSession({
      client_id: 'device-1',
      destination_id: 'room_3'
    }),
    function (error) {
      return error.code === 'ACTIVE_SESSION_EXISTS' && error.status === 409;
    }
  );
});

test('stores invalid simulator RSSI but does not send it to positioning', async function () {
  const context = setup();
  await context.service.createSession({
    client_id: 'device-1',
    destination_id: 'room_2'
  });

  await assert.rejects(
    context.service.submitObservation({
      client_id: 'device-1',
      associated_ap: 'AP2',
      rssi: -100,
      timestamp: '2026-07-24T10:00:00.000Z'
    }),
    function (error) {
      return error.code === 'INVALID_RSSI' && error.status === 400;
    }
  );
  assert.equal(context.repository.observations.length, 1);
  assert.equal(context.repository.observations[0].valid, false);
});

test('confirms roaming after three consecutive AP observations and emits route', async function () {
  const context = setup();
  const created = await context.service.createSession({
    client_id: 'device-1',
    destination_id: 'room_3'
  });
  const roamingEvents = [];
  const routeEvents = [];
  context.events.on('navigation:roaming', function (event) { roamingEvents.push(event); });
  context.events.on('navigation:route', function (event) { routeEvents.push(event); });

  await context.service.submitObservation({ client_id: 'device-1', associated_ap: 'AP1', rssi: -60 });
  await context.service.submitObservation({ client_id: 'device-1', associated_ap: 'AP2', rssi: -72 });
  await context.service.submitObservation({ client_id: 'device-1', associated_ap: 'AP2', rssi: -68 });
  const result = await context.service.submitObservation({
    client_id: 'device-1',
    associated_ap: 'AP2',
    rssi: -65
  });

  assert.equal(result.positioning.roaming_confirmed, true);
  assert.equal(result.positioning.previous_ap, 'AP1');
  assert.equal(result.session.confirmed_ap, 'AP2');
  assert.equal(roamingEvents.length, 1);
  assert.equal(routeEvents.length, 2);
  assert.equal(result.session.route_version, 2);
  assert.equal(result.session.session_id, created.session_id);
});

test('enforces anonymous client ownership and clears positioning state on completion', async function () {
  const context = setup();
  const created = await context.service.createSession({
    client_id: 'device-1',
    destination_id: 'room_1'
  });

  await assert.rejects(
    context.service.getSession(created.session_id, 'device-2'),
    function (error) {
      return error.code === 'FORBIDDEN' && error.status === 403;
    }
  );
  const completed = await context.service.completeSession(
    created.session_id,
    'device-1',
    'completed'
  );
  assert.equal(completed.status, 'completed');
  assert.equal(await context.positioning.getSession(created.session_id), null);
});

test('requires a client id when reading an anonymous session', async function () {
  const context = setup();
  const created = await context.service.createSession({
    client_id: 'device-1',
    destination_id: 'room_1'
  });

  await assert.rejects(
    context.service.getSession(created.session_id, ''),
    function (error) {
      return error.code === 'CLIENT_ID_REQUIRED' && error.status === 400;
    }
  );
});

test('health reports repository and mock positioning readiness', async function () {
  const context = setup();
  const health = await context.service.health();
  assert.equal(health.status, 'ok');
  assert.equal(health.services.mongodb, 'ok');
  assert.equal(health.services.positioning_engine, 'ok');
});
