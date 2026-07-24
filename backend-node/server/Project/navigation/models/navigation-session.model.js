'use strict';

const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const pointSchema = new Schema({
  x: { type: Number, required: true },
  y: { type: Number, required: true }
}, { _id: false });

const navigationSessionSchema = new Schema({
  sessionId: { type: String, required: true, unique: true, index: true },
  userId: { type: String, required: true, index: true },
  clientId: { type: String, required: true, index: true },
  destinationId: { type: String, required: true },
  status: {
    type: String,
    enum: ['active', 'completed', 'cancelled', 'expired'],
    default: 'active',
    index: true
  },
  observationStatus: {
    type: String,
    enum: ['waiting', 'fresh', 'stale', 'unavailable'],
    default: 'waiting'
  },
  currentAp: { type: String, default: null },
  currentZone: { type: String, default: null },
  zoneLabel: { type: String, default: null },
  signalBand: { type: String, default: null },
  medianRssi: { type: Number, default: null },
  estimatedPosition: { type: pointSchema, default: null },
  positionSource: { type: String, default: null },
  confidence: { type: String, default: null },
  route: { type: [pointSchema], default: [] },
  routeVersion: { type: Number, default: 0 },
  lastObservationAt: { type: Date, default: null },
  completedAt: { type: Date, default: null }
}, { timestamps: true });

navigationSessionSchema.index(
  { userId: 1, status: 1 },
  { partialFilterExpression: { status: 'active' } }
);
navigationSessionSchema.index(
  { clientId: 1, status: 1 },
  { partialFilterExpression: { status: 'active' } }
);

module.exports = mongoose.model(
  'Navigation_Session',
  navigationSessionSchema,
  'Navigation_Sessions'
);
