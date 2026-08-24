'use strict';

function numberFromEnv(name, fallback) {
  const value = Number(process.env[name]);
  return Number.isFinite(value) ? value : fallback;
}

module.exports = {
  positioningMode: String(process.env.POSITIONING_MODE || 'mock').toLowerCase(),
  positioningServiceUrl: process.env.POSITIONING_SERVICE_URL || 'http://127.0.0.1:8001',
  positioningTimeoutMs: numberFromEnv('POSITIONING_SERVICE_TIMEOUT_MS', 5000),
  staleAfterMs: numberFromEnv('POSITIONING_STALE_AFTER_MS', 10000),
  roamingConfirmations: numberFromEnv('POSITIONING_ROAMING_CONFIRMATIONS', 3),
  simulatorEnabled: String(process.env.POSITIONING_SIMULATOR_ENABLED || 'true').toLowerCase() === 'true',
  observationSource: String(process.env.NAVIGATION_OBSERVATION_SOURCE || 'mobile').toLowerCase(),
  destinations: {
    room_1: { id: 'room_1', label: 'Room 1 entrance', floorId: 'floor-1', position: { x: 15, y: 5 } },
    room_2: { id: 'room_2', label: 'Room 2 entrance', floorId: 'floor-1', position: { x: 15, y: 9 } },
    room_3: { id: 'room_3', label: 'Room 3 entrance', floorId: 'floor-1', position: { x: 11, y: 5 } }
  },
  accessPoints: {
    AP1: {
      name: 'AP1',
      position: { x: 17, y: 5 },
      zone: 'RIGHT_WING',
      zoneLabel: 'Room 1 / right hallway area',
      startAnchor: { x: 15, y: 6 },
      anchors: {
        near: { x: 16.125, y: 8.125 },
        medium: { x: 15.125, y: 6.125 },
        edge: { x: 14.125, y: 4.125 }
      }
    },
    AP2: {
      name: 'AP2',
      position: { x: 10.5, y: 9.75 },
      zone: 'CENTRAL_HALLWAY',
      zoneLabel: 'Central hallway / Room 2 area',
      startAnchor: { x: 12, y: 4 },
      anchors: {
        near: { x: 11.125, y: 7.125 },
        medium: { x: 12.125, y: 4.125 },
        edge: { x: 9.125, y: 3.625 }
      }
    },
    AP3: {
      name: 'AP3',
      position: { x: 2, y: 0.5 },
      zone: 'LEFT_WING',
      zoneLabel: 'Room 3 / left hallway area',
      startAnchor: { x: 6, y: 2 },
      anchors: {
        near: { x: 3.125, y: 2.125 },
        medium: { x: 6.125, y: 2.125 },
        edge: { x: 9.125, y: 3.625 }
      }
    }
  },
  transitions: {
    'AP3->AP2': { x: 9.125, y: 3.625 },
    'AP2->AP3': { x: 9.125, y: 3.625 },
    'AP2->AP1': { x: 14.125, y: 4.125 },
    'AP1->AP2': { x: 14.125, y: 4.125 }
  }
};
