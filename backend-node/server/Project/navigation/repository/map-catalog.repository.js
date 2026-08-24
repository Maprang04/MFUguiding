'use strict';

const config = require('../config/navigation.config');
const Floor = require('../models/floor.model');
const Destination = require('../models/destination.model');
const AccessPoint = require('../models/access-point.model');
const Zone = require('../models/zone.model');

function clean(document) {
  if (!document) return null;
  const result = Object.assign({}, document);
  delete result._id;
  delete result.__v;
  return result;
}

function fallbackDestinations() {
  return Object.values(config.destinations);
}

function fallbackAccessPoints() {
  return Object.values(config.accessPoints);
}

const fallbackCatalog = {
  listDestinations: async function () { return fallbackDestinations(); },
  findDestination: async function (id) { return config.destinations[id] || null; },
  listAccessPoints: async function () { return fallbackAccessPoints(); },
  hasAccessPoint: async function (id) { return Boolean(config.accessPoints[id]); },
  snapshot: async function () {
    return {
      source: 'fallback',
      floors: [],
      destinations: fallbackDestinations(),
      access_points: fallbackAccessPoints(),
      zones: [],
      transitions: config.transitions
    };
  }
};

const mongoCatalog = {
  listDestinations: async function () {
    const items = await Destination.find({ active: true }).sort({ label: 1 }).lean();
    return items.map(function (item) {
      return {
        id: item.destinationId,
        label: item.label,
        nameTh: item.nameTh,
        nameEn: item.nameEn,
        roomNumber: item.roomNumber,
        category: item.category,
        searchKeywords: item.searchKeywords,
        floorId: item.floorId,
        position: item.position
      };
    });
  },
  findDestination: async function (id) {
    const item = await Destination.findOne({ destinationId: id, active: true }).lean();
    if (!item) return null;
    return {
      id: item.destinationId,
      label: item.label,
      nameTh: item.nameTh,
      nameEn: item.nameEn,
      roomNumber: item.roomNumber,
      category: item.category,
      searchKeywords: item.searchKeywords,
      floorId: item.floorId,
      position: item.position
    };
  },
  listAccessPoints: async function () {
    const zones = await Zone.find({ active: true }).lean();
    const labels = Object.fromEntries(zones.map(function (zone) {
      return [zone.zoneId, zone.label];
    }));
    const items = await AccessPoint.find({ active: true }).sort({ apId: 1 }).lean();
    return items.map(function (item) {
      return {
        name: item.apId,
        floorId: item.floorId,
        bssid: item.bssid,
        position: item.position,
        zone: item.zoneId,
        zoneLabel: labels[item.zoneId] || item.zoneId,
        startAnchor: item.startAnchor || item.anchors.medium,
        anchors: item.anchors,
        lastSeenAt: item.lastSeenAt
      };
    });
  },
  hasAccessPoint: async function (id) {
    return Boolean(await AccessPoint.exists({ apId: id, active: true }));
  },
  snapshot: async function () {
    const [floors, destinations, accessPoints, zones] = await Promise.all([
      Floor.find({ active: true }).sort({ floorId: 1 }).lean(),
      mongoCatalog.listDestinations(),
      mongoCatalog.listAccessPoints(),
      Zone.find({ active: true }).sort({ zoneId: 1 }).lean()
    ]);
    const transitions = {};
    zones.forEach(function (zone) {
      (zone.transitions || []).forEach(function (transition) {
        transitions[transition.fromAp + '->' + transition.toAp] = transition.position;
      });
    });
    return {
      source: 'mongodb',
      floors: floors.map(clean),
      destinations,
      access_points: accessPoints,
      zones: zones.map(clean),
      transitions
    };
  }
};

module.exports = mongoCatalog;
module.exports.fallback = fallbackCatalog;
