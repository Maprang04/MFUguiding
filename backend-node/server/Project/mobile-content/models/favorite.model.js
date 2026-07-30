'use strict';

const mongoose = require('mongoose');
const database = require('../../../database/indoor-navigation.connection');
const Schema = mongoose.Schema;

const favoriteSchema = new Schema({
  userId: { type: Schema.Types.ObjectId, required: true, index: true },
  destinationId: { type: String, required: true, trim: true },
  tag: { type: String, enum: ['Home', 'Study', 'Others'], default: 'Others' },
  createdAt: { type: Date, default: Date.now }
}, { collection: 'Mobile_Favorites' });

favoriteSchema.index({ userId: 1, destinationId: 1 }, { unique: true });

module.exports = database.models.MobileFavorite ||
  database.model('MobileFavorite', favoriteSchema);
