'use strict';

const mongoose = require('mongoose');
const database = require('../../../database/indoor-navigation.connection');
const Schema = mongoose.Schema;

const pointSchema = new Schema({
  x: { type: Number, required: true },
  y: { type: Number, required: true }
}, { _id: false });

const reportSchema = new Schema({
  userId: { type: Schema.Types.ObjectId, required: true, index: true },
  reporterEmail: { type: String, required: true, trim: true },
  type: { type: String, required: true, trim: true },
  location: { type: String, required: true, trim: true },
  description: { type: String, required: true, trim: true },
  navigationSessionId: { type: String, default: null, index: true },
  estimatedPosition: { type: pointSchema, default: null },
  status: {
    type: String,
    enum: ['pending', 'approved', 'rejected', 'in_progress', 'resolved'],
    default: 'pending',
    index: true
  },
  createdAt: { type: Date, default: Date.now, index: true },
  updatedAt: { type: Date, default: Date.now }
}, { collection: 'Mobile_Reports' });

module.exports = database.models.MobileReport ||
  database.model('MobileReport', reportSchema);
