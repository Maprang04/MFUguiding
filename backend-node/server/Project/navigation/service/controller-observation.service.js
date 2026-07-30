'use strict';

const config = require('../config/navigation.config');
const AccessPoint = require('../models/access-point.model');
const repository = require('../repository/navigation.repository');
const navigation = require('./navigation-session.service');

function error(status, code, message) {
  return Object.assign(new Error(message), { status, code });
}

function clean(value) {
  return String(value || '').trim();
}

async function mapAccessPoint(identifier) {
  const value = clean(identifier);
  if (!value) throw error(400, 'AP_REQUIRED', 'associated_ap is required');
  const escaped = value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const item = await AccessPoint.findOne({
    active: true,
    $or: [
      { apId: value },
      { controllerApId: value },
      { bssid: new RegExp('^' + escaped + '$', 'i') }
    ]
  }).lean();
  if (!item) throw error(400, 'UNKNOWN_ACCESS_POINT', 'Controller AP is not mapped');
  return item.apId;
}

async function ingest(input, now) {
  const clock = now || new Date();
  const observationId = clean(input && input.observation_id);
  const clientId = clean(input && (input.client_id || input.client_mac));
  const timestamp = new Date(input && input.timestamp);
  const rssi = Number(input && input.rssi);
  if (!observationId || !clientId || Number.isNaN(timestamp.getTime())) {
    throw error(
      400,
      'INVALID_CONTROLLER_OBSERVATION',
      'observation_id, client_id/client_mac and timestamp are required'
    );
  }
  if (clock.getTime() - timestamp.getTime() > config.controllerMaxAgeMs) {
    throw error(409, 'STALE_CONTROLLER_OBSERVATION', 'Controller observation is too old');
  }
  if (timestamp.getTime() - clock.getTime() > config.controllerFutureSkewMs) {
    throw error(400, 'FUTURE_CONTROLLER_OBSERVATION', 'Controller timestamp is in the future');
  }
  if (await repository.observationExists(observationId)) {
    return { accepted: false, duplicate: true, observation_id: observationId };
  }
  const associatedAp = await mapAccessPoint(input.associated_ap || input.ap_id || input.bssid);
  const result = await navigation.submitObservation({
    observation_id: observationId,
    client_id: clientId,
    associated_ap: associatedAp,
    rssi,
    timestamp: timestamp.toISOString(),
    source: 'cisco-controller'
  });
  return Object.assign({
    accepted: true,
    duplicate: false,
    observation_id: observationId,
    mapped_ap: associatedAp
  }, result);
}

module.exports = { ingest, mapAccessPoint };
