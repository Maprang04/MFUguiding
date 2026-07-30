'use strict';

const mongoose = require('mongoose');
const database = require('../../../database/indoor-navigation.connection');
const Schema = mongoose.Schema;

const mobileSessionSchema = new Schema({
  tokenHash: { type: String, required: true, unique: true, index: true },
  userId: { type: Schema.Types.ObjectId, required: true, index: true },
  expiresAt: { type: Date, required: true, index: { expires: 0 } },
  createdAt: { type: Date, default: Date.now },
  revokedAt: { type: Date, default: null }
}, { collection: 'Mobile_Sessions' });

module.exports = database.models.MobileSession ||
  database.model('MobileSession', mobileSessionSchema);
