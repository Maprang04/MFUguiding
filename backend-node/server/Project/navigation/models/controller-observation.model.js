'use strict';

const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const controllerObservationSchema = new Schema({
  sessionId: { type: String, default: null, index: true },
  clientId: { type: String, required: true, index: true },
  associatedAp: { type: String, required: true, index: true },
  rssi: { type: Number, required: true },
  timestamp: { type: Date, required: true, index: true },
  receivedAt: { type: Date, default: Date.now },
  source: { type: String, default: 'simulator' },
  valid: { type: Boolean, default: true },
  validationError: { type: String, default: null }
}, { timestamps: true });

controllerObservationSchema.index({ sessionId: 1, timestamp: -1 });
controllerObservationSchema.index({ clientId: 1, timestamp: -1 });
controllerObservationSchema.index({ associatedAp: 1, timestamp: -1 });

module.exports = mongoose.model(
  'Controller_Observation',
  controllerObservationSchema,
  'Controller_Observations'
);
