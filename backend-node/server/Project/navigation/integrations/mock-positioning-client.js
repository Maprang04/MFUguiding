'use strict';

const navigationConfig = require('../config/navigation.config');

function median(values) {
  const sorted = values.slice().sort(function (a, b) { return a - b; });
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2
    ? sorted[middle]
    : (sorted[middle - 1] + sorted[middle]) / 2;
}

function signalBand(rssi) {
  if (rssi >= -55) return 'near';
  if (rssi >= -70) return 'medium';
  return 'edge';
}

class MockPositioningClient {
  constructor(config) {
    this.config = config || navigationConfig;
    this.sessions = new Map();
  }

  async healthCheck() {
    return { status: 'ok', mode: 'mock' };
  }

  async createSession(input) {
    const state = {
      sessionId: input.session_id,
      clientId: input.client_id,
      destinationId: input.destination_id,
      currentAp: null,
      candidateAp: null,
      candidateCount: 0,
      windows: {},
      currentPosition: input.start_position || null,
      route: []
    };
    if (state.currentPosition) {
      state.route = [state.currentPosition, this.config.destinations[state.destinationId].position];
      state.hasRoute = true;
    }
    this.sessions.set(input.session_id, state);
    return {
      session_id: input.session_id,
      status: 'ready',
      estimated_position: state.currentPosition,
      route: state.route
    };
  }

  async submitObservation(sessionId, observation) {
    const state = this.sessions.get(sessionId);
    if (!state) {
      const error = new Error('Positioning session not found');
      error.code = 'POSITIONING_SESSION_NOT_FOUND';
      error.status = 404;
      throw error;
    }

    const ap = observation.associated_ap;
    const apConfig = this.config.accessPoints[ap];
    if (!apConfig) {
      const error = new Error('Unknown access point: ' + ap);
      error.code = 'UNKNOWN_ACCESS_POINT';
      error.status = 400;
      throw error;
    }
    if (!state.windows[ap]) state.windows[ap] = [];
    state.windows[ap].push(Number(observation.rssi));
    state.windows[ap] = state.windows[ap].slice(-5);

    let roamingConfirmed = false;
    let previousAp = null;
    if (!state.currentAp) {
      state.currentAp = ap;
    } else if (ap === state.currentAp) {
      state.candidateAp = null;
      state.candidateCount = 0;
    } else {
      if (state.candidateAp === ap) {
        state.candidateCount += 1;
      } else {
        state.candidateAp = ap;
        state.candidateCount = 1;
      }
      if (state.candidateCount >= this.config.roamingConfirmations) {
        previousAp = state.currentAp;
        state.currentAp = ap;
        state.candidateAp = null;
        state.candidateCount = 0;
        roamingConfirmed = true;
      }
    }

    const confirmedAp = state.currentAp;
    const confirmedConfig = this.config.accessPoints[confirmedAp];
    const confirmedMedian = median(state.windows[confirmedAp] || [observation.rssi]);
    const band = signalBand(confirmedMedian);
    const transition = previousAp
      ? this.config.transitions[previousAp + '->' + confirmedAp]
      : null;
    const position = transition || confirmedConfig.anchors[band];
    const destination = this.config.destinations[state.destinationId];

    const routeRecalculated = roamingConfirmed || !state.hasRoute;
    if (routeRecalculated) state.hasRoute = true;
    return {
      confirmed_ap: confirmedAp,
      candidate_ap: state.candidateAp,
      candidate_count: state.candidateCount,
      roaming_confirmed: roamingConfirmed,
      previous_ap: previousAp,
      zone: confirmedConfig.zone,
      zone_label: confirmedConfig.zoneLabel,
      signal_band: band,
      median_rssi: confirmedMedian,
      estimated_position: position,
      position_source: transition ? 'roaming_transition' : 'zone_anchor',
      confidence: transition ? 'high' : (state.windows[confirmedAp].length > 1 ? 'medium' : 'low'),
      route_recalculated: routeRecalculated,
      route: [position, destination.position]
    };
  }

  async changeDestination(sessionId, destinationId) {
    const state = this.sessions.get(sessionId);
    if (!state) throw new Error('Positioning session not found');
    state.destinationId = destinationId;
    state.hasRoute = false;
    return { session_id: sessionId, destination_id: destinationId };
  }

  async advanceProgress(sessionId, input) {
    const state = this.sessions.get(sessionId);
    if (!state || !state.currentPosition || state.route.length < 2) {
      const error = new Error('A route is required before progress');
      error.code = 'ROUTE_NOT_READY';
      throw error;
    }
    const destination = state.route[state.route.length - 1];
    const dx = destination.x - state.currentPosition.x;
    const dy = destination.y - state.currentPosition.y;
    const remaining = Math.hypot(dx, dy);
    const distance = Math.min(Number(input.distance_meters), remaining);
    const ratio = remaining ? distance / remaining : 1;
    state.currentPosition = {
      x: state.currentPosition.x + dx * ratio,
      y: state.currentPosition.y + dy * ratio
    };
    state.distanceTravelled = (state.distanceTravelled || 0) + distance;
    state.route = [state.currentPosition, destination];
    return {
      estimated_position: state.currentPosition,
      route: state.route,
      distance_delta: distance,
      distance_travelled: state.distanceTravelled,
      arrived: distance >= remaining,
      position_source: 'step_route_progress'
    };
  }

  async getSession(sessionId) {
    return this.sessions.get(sessionId) || null;
  }

  async deleteSession(sessionId) {
    this.sessions.delete(sessionId);
    return { deleted: true };
  }
}

module.exports = MockPositioningClient;
