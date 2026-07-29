'use strict';

const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const transformSchema = new Schema({
  a: { type: Number, required: true },
  b: { type: Number, required: true },
  c: { type: Number, required: true },
  d: { type: Number, required: true }
}, { _id: false });

const floorSchema = new Schema({
  floorId: { type: String, required: true, unique: true, index: true, trim: true },
  buildingId: { type: String, required: true, index: true, trim: true },
  label: { type: String, required: true, trim: true },
  imageAsset: { type: String, required: true, trim: true },
  imageWidth: { type: Number, required: true, min: 1 },
  imageHeight: { type: Number, required: true, min: 1 },
  cellSizeMeters: { type: Number, required: true, min: 0.01 },
  xRange: { type: [Number], required: true },
  yRange: { type: [Number], required: true },
  transform: { type: transformSchema, required: true },
  active: { type: Boolean, default: true, index: true },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
}, { collection: 'Navigation_Floors' });

module.exports = mongoose.models.NavigationFloor ||
  mongoose.model('NavigationFloor', floorSchema);
