'use strict';

const mongoose = require('mongoose');
const database = require('../../../database/indoor-navigation.connection');
const Schema = mongoose.Schema;

const pointSchema = new Schema({
  x: { type: Number, required: true },
  y: { type: Number, required: true }
}, { _id: false });

const destinationSchema = new Schema({
  destinationId: { type: String, required: true, unique: true, index: true, trim: true },
  floorId: { type: String, required: true, index: true, trim: true },
  label: { type: String, required: true, trim: true },
  nameTh: { type: String, default: null, trim: true },
  nameEn: { type: String, required: true, trim: true },
  roomNumber: { type: String, default: null, trim: true, index: true },
  category: { type: String, default: 'room', trim: true },
  searchKeywords: { type: [String], default: [] },
  position: { type: pointSchema, required: true },
  active: { type: Boolean, default: true, index: true },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
}, { collection: 'Navigation_Destinations' });

destinationSchema.index({
  label: 'text',
  nameTh: 'text',
  nameEn: 'text',
  roomNumber: 'text',
  searchKeywords: 'text'
});

module.exports = database.models.NavigationDestination ||
  database.model('NavigationDestination', destinationSchema);
