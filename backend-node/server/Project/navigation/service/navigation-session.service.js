'use strict';

const crypto = require('crypto');
const config = require('../config/navigation.config');
const defaultRepository = require('../repository/navigation.repository');
const defaultCatalog = require('../repository/map-catalog.repository');
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
    start_position: session.startPosition,
    start_position_source: session.startPositionSource,
    total_steps: session.totalSteps || 0,
    stride_length: session.strideLength || 0.65,
    distance_travelled: session.distanceTravelled || 0,
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
  const catalog = deps.catalog ||
    (deps.repository ? defaultCatalog.fallback : defaultCatalog);
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
    const start = input && input.start_position;
    const startPosition = start && Number.isFinite(Number(start.x)) && Number.isFinite(Number(start.y))
      ? { x: Number(start.x), y: Number(start.y) }
      : null;
    if (!clientId || !destinationId) {
      throw serviceError(400, 'INVALID_REQUEST', 'client_id and destination_id are required');
    }
    if (!await catalog.findDestination(destinationId)) {
      throw serviceError(404, 'DESTINATION_NOT_FOUND', 'Destination does not exist');
    }
    const anonymousUserId = 'anonymous:' + clientId;
    const existing = await repository.findActiveByUserOrClient(anonymousUserId, clientId);
    if (existing) {
      throw serviceError(409, 'ACTIVE_SESSION_EXISTS', 'An active navigation session already exists');
    }

    if (typeof positioning.configure === 'function') {
      await positioning.configure(await catalog.snapshot());
    }
    const sessionId = safeSessionId();
    const positioningSession = await positioning.createSession({
      session_id: sessionId,
      client_id: clientId,
      destination_id: destinationId,
      start_position: startPosition
    });
    const created = await repository.createSession({
      sessionId,
      userId: anonymousUserId,
      clientId,
      destinationId,
      startPosition,
      startPositionSource: cleanText(input && input.start_position_source) ||
        (startPosition ? 'user_selected' : null),
      estimatedPosition: positioningSession.estimated_position || null,
      positionSource: startPosition ? 'user_selected_start' : null,
      route: positioningSession.route || [],
      routeVersion: positioningSession.route && positioningSession.route.length ? 1 : 0,
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
    const rawRssiReadings = input && input.rssi_readings;
    const rssiReadings = {};
    if (rawRssiReadings && typeof rawRssiReadings === 'object') {
      for (const apName of ['AP1', 'AP2', 'AP3']) {
        const value = Number(rawRssiReadings[apName]);
        if (Number.isFinite(value) && value > -95 && value < -20) {
          rssiReadings[apName] = value;
        }
      }
    }
    const timestamp = input && input.timestamp ? new Date(input.timestamp) : clock();
    const externalObservationId = cleanText(input && input.observation_id);
    if (!clientId || !associatedAp || Number.isNaN(timestamp.getTime())) {
      throw serviceError(400, 'INVALID_REQUEST', 'client_id, associated_ap and a valid timestamp are required');
    }

    const session = await repository.findActiveByClient(clientId);
    if (!session) {
      throw serviceError(404, 'SESSION_NOT_FOUND', 'No active navigation session for this client');
    }

    const validRssi = Number.isFinite(rssi) && rssi > -95 && rssi < -20;
    const knownAp = await catalog.hasAccessPoint(associatedAp);
    const validationError = !validRssi
      ? 'RSSI must be a number between -95 and -20 dBm'
      : (!knownAp ? 'Unknown access point' : null);

    const observationRecord = {
      sessionId: session.sessionId,
      clientId,
      associatedAp,
      rssi: Number.isFinite(rssi) ? rssi : 0,
      rssiReadings: Object.keys(rssiReadings).length ? rssiReadings : null,
      timestamp,
      receivedAt: clock(),
      source: cleanText(input.source) || 'simulator',
      valid: !validationError,
      validationError
    };
    if (externalObservationId) {
      observationRecord.externalObservationId = externalObservationId;
    }
    await repository.createObservation(observationRecord);
    if (validationError) {
      throw serviceError(
        400,
        validRssi ? 'UNKNOWN_ACCESS_POINT' : 'INVALID_RSSI',
        validationError
      );
    }

    const positioningObservation = {
      associated_ap: associatedAp,
      rssi,
      rssi_readings: Object.keys(rssiReadings).length === 3
        ? rssiReadings
        : null,
      timestamp: timestamp.toISOString()
    };
    let result;
    try {
      result = await positioning.submitObservation(
        session.sessionId,
        positioningObservation
      );
    } catch (cause) {
      if (cause && cause.code === 'POSITIONING_SESSION_NOT_FOUND') {
        if (typeof positioning.configure === 'function') {
          await positioning.configure(await catalog.snapshot());
        }
        await positioning.createSession({
          session_id: session.sessionId,
          client_id: session.clientId,
          destination_id: session.destinationId,
          start_position: session.estimatedPosition || session.startPosition || null
        });
        result = await positioning.submitObservation(
          session.sessionId,
          positioningObservation
        );
      } else {
        throw cause;
      }
    }
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

  async function submitProgress(sessionId, clientId, input) {
    const session = await requireOwnedSession(sessionId, clientId, false);
    const stepsDelta = Number(input && input.steps_delta);
    const strideLength = Number(input && input.stride_length);
    const motionDistance = Number(input && input.motion_distance_meters);
    const usesMotionDistance = Number.isFinite(motionDistance);
    const timestamp = input && input.timestamp ? new Date(input.timestamp) : clock();
    if ((!usesMotionDistance &&
          (!Number.isInteger(stepsDelta) || stepsDelta <= 0 || stepsDelta > 30 ||
           !Number.isFinite(strideLength) || strideLength < 0.35 || strideLength > 1.2)) ||
        (usesMotionDistance && (motionDistance < 0.1 || motionDistance > 2)) ||
        Number.isNaN(timestamp.getTime())) {
      throw serviceError(400, 'INVALID_PROGRESS', 'motion distance or step progress is invalid');
    }
    const distance = usesMotionDistance
      ? motionDistance
      : Math.min(20, stepsDelta * strideLength);
    const progressInput = { distance_meters: distance };
    let result;
    try {
      result = await positioning.advanceProgress(session.sessionId, progressInput);
    } catch (cause) {
      if (cause && cause.code === 'POSITIONING_SESSION_NOT_FOUND') {
        if (typeof positioning.configure === 'function') {
          await positioning.configure(await catalog.snapshot());
        }
        await positioning.createSession({
          session_id: session.sessionId,
          client_id: session.clientId,
          destination_id: session.destinationId,
          start_position: session.estimatedPosition || session.startPosition
        });
        result = await positioning.advanceProgress(session.sessionId, progressInput);
      } else {
        throw cause;
      }
    }
    const updated = await repository.updateSession(session.sessionId, {
      estimatedPosition: result.estimated_position,
      positionSource: result.position_source,
      route: result.route || [],
      routeVersion: (session.routeVersion || 0) + 1,
      totalSteps: (session.totalSteps || 0) + (usesMotionDistance ? 0 : stepsDelta),
      strideLength: usesMotionDistance ? session.strideLength : strideLength,
      distanceTravelled: result.distance_travelled,
      lastProgressAt: timestamp
    });
    events.emit('navigation:position', {
      sessionId: session.sessionId,
      data: publicSession(updated)
    });
    return { session: publicSession(updated), progress: result };
  }

  async function changeDestination(sessionId, destinationId, clientId) {
    const session = await requireOwnedSession(sessionId, clientId, false);
    if (!await catalog.findDestination(destinationId)) {
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
      observation_source: config.observationSource
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
    submitProgress,
    changeDestination,
    completeSession,
    listObservations,
    health,
    destinations: function () { return catalog.listDestinations(); },
    destination: function (id) { return catalog.findDestination(id); },
    accessPoints: function () { return catalog.listAccessPoints(); },
    mapConfig: function () { return catalog.snapshot(); },
    _private: { publicSession, requireOwnedSession }
  };
}

module.exports = createNavigationService();
module.exports.createService = createNavigationService;
module.exports.serviceError = serviceError;
