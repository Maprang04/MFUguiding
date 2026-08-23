'use strict';

const mongoose = require('mongoose');
const database = require('../../../database/indoor-navigation.connection');
const Schema = mongoose.Schema;

const navigationObservationSchema = new Schema({
  sessionId: { type: String, default: null, index: true },
  clientId: { type: String, required: true, index: true },
  associatedAp: { type: String, required: true, index: true },
  rssi: { type: Number, required: true },
  rssiReadings: { type: Map, of: Number, default: null },
  timestamp: { type: Date, required: true, index: true },
  receivedAt: { type: Date, default: Date.now },
  source: { type: String, default: 'mobile_connected_ap' },
  valid: { type: Boolean, default: true },
  validationError: { type: String, default: null },
  externalObservationId: { type: String, sparse: true, unique: true }
}, { timestamps: true });

navigationObservationSchema.index({ sessionId: 1, timestamp: -1 });
navigationObservationSchema.index({ clientId: 1, timestamp: -1 });
navigationObservationSchema.index({ associatedAp: 1, timestamp: -1 });

module.exports = database.models.Navigation_Observation ||
  database.model(
    'Navigation_Observation',
    navigationObservationSchema,
    'Navigation_Observations'
  );
