'use strict';

const mongoose = require('mongoose');
const database = require('../../../database/indoor-navigation.connection');
const Schema = mongoose.Schema;

const pointSchema = new Schema({
  x: { type: Number, required: true },
  y: { type: Number, required: true }
}, { _id: false });

const transitionSchema = new Schema({
  fromAp: { type: String, required: true },
  toAp: { type: String, required: true },
  position: { type: pointSchema, required: true }
}, { _id: false });

const zoneSchema = new Schema({
  zoneId: { type: String, required: true, unique: true, index: true, trim: true },
  floorId: { type: String, required: true, index: true, trim: true },
  label: { type: String, required: true, trim: true },
  transitions: { type: [transitionSchema], default: [] },
  active: { type: Boolean, default: true, index: true },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
}, { collection: 'Navigation_Zones' });

module.exports = database.models.NavigationZone ||
  database.model('NavigationZone', zoneSchema);
