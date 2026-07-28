'use strict';

const crypto = require('crypto');
const config = require('../config/navigation.config');
const defaultRepository = require('../repository/navigation.repository');
const createPositioningClient = require('../integrations/positioning-client.factory');
const defaultEvents = require('../navigation.events');

function serviceError(status, code, message) {
  const error = new Error(message);
  error.status = status;
  error.code = code;
  return error;
}

function cleanText(value) {
  const text = String(value || '').trim();
  return text || null;
}

function safeSessionId() {
  return typeof crypto.randomUUID === 'function'
    ? 'nav-' + crypto.randomUUID()
    : 'nav-' + crypto.randomBytes(16).toString('hex');
}

function publicSession(session) {
  if (!session) return null;
  return {
    session_id: session.sessionId,
    status: session.status,
    observation_status: session.observationStatus,
    client_id: session.clientId,
    destination_id: session.destinationId,
    confirmed_ap: session.currentAp,
    zone: session.currentZone,
    zone_label: session.zoneLabel,
    signal_band: session.signalBand,
    median_rssi: session.medianRssi,
    estimated_position: session.estimatedPosition,
    position_source: session.positionSource,
    confidence: session.confidence,
    route: session.route || [],
    route_version: session.routeVersion || 0,
    last_observation_at: session.lastObservationAt,
    started_at: session.createdAt,
    updated_at: session.updatedAt,
    completed_at: session.completedAt
  };
}

function createNavigationService(dependencies) {
  const deps = dependencies || {};
  const repository = deps.repository || defaultRepository;
  const positioning = deps.positioning || createPositioningClient();
  const events = deps.events || defaultEvents;
  const clock = deps.clock || function () { return new Date(); };

  async function requireOwnedSession(sessionId, clientId, allowInactive) {
    const normalizedClientId = cleanText(clientId);
    if (!normalizedClientId) {
      throw serviceError(
        400,
        'CLIENT_ID_REQUIRED',
        'x-navigation-client-id header is required'
      );
    }
    const session = await repository.findSession(sessionId);
    if (!session) {
      throw serviceError(404, 'SESSION_NOT_FOUND', 'Navigation session not found');
    }
    if (String(session.clientId) !== normalizedClientId) {
      throw serviceError(403, 'FORBIDDEN', 'You cannot access this navigation session');
    }
    if (!allowInactive && session.status !== 'active') {
      throw serviceError(409, 'SESSION_NOT_ACTIVE', 'Navigation session is not active');
    }
    return session;
  }

  async function createSession(input) {
    const clientId = cleanText(input && input.client_id);
    const destinationId = cleanText(input && input.destination_id);
    if (!clientId || !destinationId) {
      throw serviceError(400, 'INVALID_REQUEST', 'client_id and destination_id are required');
    }
    if (!config.destinations[destinationId]) {
      throw serviceError(404, 'DESTINATION_NOT_FOUND', 'Destination does not exist');
    }
    const anonymousUserId = 'anonymous:' + clientId;
    const existing = await repository.findActiveByUserOrClient(anonymousUserId, clientId);
    if (existing) {
      throw serviceError(409, 'ACTIVE_SESSION_EXISTS', 'An active navigation session already exists');
    }

    const sessionId = safeSessionId();
    await positioning.createSession({
      session_id: sessionId,
      client_id: clientId,
      destination_id: destinationId
    });
    const created = await repository.createSession({
      sessionId,
      userId: anonymousUserId,
      clientId,
      destinationId,
      status: 'active',
      observationStatus: 'waiting'
    });
    return publicSession(created);
  }

  async function getSession(sessionId, clientId) {
    const session = await requireOwnedSession(sessionId, clientId, true);
    const lastObservation = session.lastObservationAt
      ? new Date(session.lastObservationAt).getTime()
      : null;
    if (
      session.status === 'active' &&
      lastObservation &&
      clock().getTime() - lastObservation > config.staleAfterMs
    ) {
      const updated = await repository.updateSession(sessionId, {
        observationStatus: 'stale'
      });
      return publicSession(updated);
    }
    return publicSession(session);
  }

  async function submitObservation(input) {
    const clientId = cleanText(input && input.client_id);
    const associatedAp = cleanText(input && input.associated_ap);
    const rssi = Number(input && input.rssi);
    const timestamp = input && input.timestamp ? new Date(input.timestamp) : clock();
    if (!clientId || !associatedAp || Number.isNaN(timestamp.getTime())) {
      throw serviceError(400, 'INVALID_REQUEST', 'client_id, associated_ap and a valid timestamp are required');
    }

    const session = await repository.findActiveByClient(clientId);
    if (!session) {
      throw serviceError(404, 'SESSION_NOT_FOUND', 'No active navigation session for this client');
    }

    const validRssi = Number.isFinite(rssi) && rssi > -95 && rssi < -20;
    const knownAp = Boolean(config.accessPoints[associatedAp]);
    const validationError = !validRssi
      ? 'RSSI must be a number between -95 and -20 dBm'
      : (!knownAp ? 'Unknown access point' : null);

    await repository.createObservation({
      sessionId: session.sessionId,
      clientId,
      associatedAp,
      rssi: Number.isFinite(rssi) ? rssi : 0,
      timestamp,
      receivedAt: clock(),
      source: cleanText(input.source) || 'simulator',
      valid: !validationError,
      validationError
    });
    if (validationError) {
      throw serviceError(
        400,
        validRssi ? 'UNKNOWN_ACCESS_POINT' : 'INVALID_RSSI',
        validationError
      );
    }

    const result = await positioning.submitObservation(session.sessionId, {
      associated_ap: associatedAp,
      rssi,
      timestamp: timestamp.toISOString()
    });
    const changes = {
      observationStatus: 'fresh',
      currentAp: result.confirmed_ap,
      currentZone: result.zone,
      zoneLabel: result.zone_label,
      signalBand: result.signal_band,
      medianRssi: result.median_rssi,
      estimatedPosition: result.estimated_position,
      positionSource: result.position_source,
      confidence: result.confidence,
      lastObservationAt: timestamp
    };
    if (result.route_recalculated) {
      changes.route = result.route || [];
      changes.routeVersion = (session.routeVersion || 0) + 1;
    }
    const updated = await repository.updateSession(session.sessionId, changes);

    events.emit('navigation:position', {
      sessionId: session.sessionId,
      data: publicSession(updated)
    });
    if (result.roaming_confirmed) {
      events.emit('navigation:roaming', {
        sessionId: session.sessionId,
        data: {
          session_id: session.sessionId,
          previous_ap: result.previous_ap,
          current_ap: result.confirmed_ap,
          transition_position: result.estimated_position,
          confidence: result.confidence
        }
      });
    }
    if (result.route_recalculated) {
      events.emit('navigation:route', {
        sessionId: session.sessionId,
        data: {
          session_id: session.sessionId,
          route_version: changes.routeVersion,
          route: result.route || [],
          destination_id: session.destinationId
        }
      });
    }
    return {
      accepted: true,
      session: publicSession(updated),
      positioning: result
    };
  }

  async function changeDestination(sessionId, destinationId, clientId) {
    const session = await requireOwnedSession(sessionId, clientId, false);
    if (!config.destinations[destinationId]) {
      throw serviceError(404, 'DESTINATION_NOT_FOUND', 'Destination does not exist');
    }
    await positioning.changeDestination(sessionId, destinationId);
    const updated = await repository.updateSession(sessionId, {
      destinationId,
      route: [],
      routeVersion: (session.routeVersion || 0) + 1
    });
    return publicSession(updated);
  }

  async function completeSession(sessionId, clientId, status) {
    await requireOwnedSession(sessionId, clientId, false);
    const finalStatus = status === 'cancelled' ? 'cancelled' : 'completed';
    const updated = await repository.updateSession(sessionId, {
      status: finalStatus,
      completedAt: clock()
    });
    await positioning.deleteSession(sessionId);
    events.emit('navigation:' + finalStatus, {
      sessionId,
      data: publicSession(updated)
    });
    return publicSession(updated);
  }

  async function listObservations(sessionId, clientId, limit) {
    await requireOwnedSession(sessionId, clientId, true);
    const parsed = Number(limit);
    const safeLimit = Math.min(Math.max(Number.isFinite(parsed) ? parsed : 100, 1), 500);
    return repository.listObservations(sessionId, safeLimit);
  }

  async function health() {
    const services = {
      backend: 'ok',
      mongodb: 'ok',
      positioning_engine: 'ok',
      observation_source: config.simulatorEnabled ? 'simulator' : 'controller',
      cisco_controller: 'not_configured'
    };
    try {
      await repository.healthCheck();
    } catch (_error) {
      services.mongodb = 'unavailable';
    }
    try {
      await positioning.healthCheck();
    } catch (_error) {
      services.positioning_engine = 'unavailable';
    }
    const degraded = services.mongodb !== 'ok' || services.positioning_engine !== 'ok';
    return { status: degraded ? 'degraded' : 'ok', services, timestamp: clock() };
  }

  return {
    createSession,
    getSession,
    submitObservation,
    changeDestination,
    completeSession,
    listObservations,
    health,
    destinations: function () { return Object.values(config.destinations); },
    accessPoints: function () { return Object.values(config.accessPoints); },
    _private: { publicSession, requireOwnedSession }
  };
}

module.exports = createNavigationService();
module.exports.createService = createNavigationService;
module.exports.serviceError = serviceError;
