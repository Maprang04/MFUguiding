'use strict';

const mongoose = require('mongoose');
const database = require('../../../database/indoor-navigation.connection');
const Schema = mongoose.Schema;

const pointSchema = new Schema({
  x: { type: Number, required: true },
  y: { type: Number, required: true }
}, { _id: false });

const accessPointSchema = new Schema({
  apId: { type: String, required: true, unique: true, index: true, trim: true },
  floorId: { type: String, required: true, index: true, trim: true },
  controllerApId: { type: String, default: null, sparse: true, index: true, trim: true },
  bssid: { type: String, default: null, sparse: true, index: true, trim: true },
  position: { type: pointSchema, required: true },
  zoneId: { type: String, required: true, index: true, trim: true },
  anchors: {
    near: { type: pointSchema, required: true },
    medium: { type: pointSchema, required: true },
    edge: { type: pointSchema, required: true }
  },
  active: { type: Boolean, default: true, index: true },
  lastSeenAt: { type: Date, default: null },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
}, { collection: 'Navigation_Access_Points' });

module.exports = database.models.NavigationAccessPoint ||
  database.model('NavigationAccessPoint', accessPointSchema);
