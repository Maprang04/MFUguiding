'use strict';

const Floor = require('../models/floor.model');
const Destination = require('../models/destination.model');
const AccessPoint = require('../models/access-point.model');
const Zone = require('../models/zone.model');

function error(status, code, message) {
  return Object.assign(new Error(message), { status, code });
}

const resources = {
  floors: { Model: Floor, key: 'floorId' },
  destinations: { Model: Destination, key: 'destinationId' },
  'access-points': { Model: AccessPoint, key: 'apId' },
  zones: { Model: Zone, key: 'zoneId' }
};

function resource(name) {
  const selected = resources[name];
  if (!selected) throw error(404, 'RESOURCE_NOT_FOUND', 'Map resource does not exist');
  return selected;
}

function publicDocument(document) {
  if (!document) return null;
  const item = Object.assign({}, document);
  item.id = item.floorId || item.destinationId || item.apId || item.zoneId;
  delete item._id;
  delete item.__v;
  return item;
}

async function list(name, includeInactive) {
  const selected = resource(name);
  const query = includeInactive ? {} : { active: true };
  const items = await selected.Model.find(query).sort({ [selected.key]: 1 }).lean();
  return items.map(publicDocument);
}

async function get(name, id) {
  const selected = resource(name);
  const item = await selected.Model.findOne({ [selected.key]: id }).lean();
  if (!item) throw error(404, 'MAP_ITEM_NOT_FOUND', 'Map item does not exist');
  return publicDocument(item);
}

async function create(name, payload) {
  const selected = resource(name);
  if (!payload || !String(payload[selected.key] || '').trim()) {
    throw error(400, 'INVALID_REQUEST', selected.key + ' is required');
  }
  try {
    const created = await selected.Model.create(Object.assign({}, payload, {
      createdAt: new Date(),
      updatedAt: new Date()
    }));
    return publicDocument(created.toObject());
  } catch (cause) {
    if (cause && cause.code === 11000) {
      throw error(409, 'MAP_ITEM_EXISTS', 'Map item already exists');
    }
    if (cause && cause.name === 'ValidationError') {
      throw error(400, 'INVALID_REQUEST', cause.message);
    }
    throw cause;
  }
}

async function update(name, id, payload) {
  const selected = resource(name);
  const changes = Object.assign({}, payload);
  delete changes[selected.key];
  delete changes._id;
  delete changes.id;
  delete changes.createdAt;
  changes.updatedAt = new Date();
  try {
    const item = await selected.Model.findOneAndUpdate(
      { [selected.key]: id },
      { $set: changes },
      { new: true, runValidators: true }
    ).lean();
    if (!item) throw error(404, 'MAP_ITEM_NOT_FOUND', 'Map item does not exist');
    return publicDocument(item);
  } catch (cause) {
    if (cause && cause.name === 'ValidationError') {
      throw error(400, 'INVALID_REQUEST', cause.message);
    }
    throw cause;
  }
}

function deactivate(name, id) {
  return update(name, id, { active: false });
}

module.exports = { create, deactivate, get, list, update };
