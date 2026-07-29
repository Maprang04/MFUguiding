'use strict';

const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const mobileUserSchema = new Schema({
  email: { type: String, required: true, unique: true, index: true, lowercase: true, trim: true },
  passwordHash: { type: String, required: true },
  passwordSalt: { type: String, required: true },
  role: { type: String, enum: ['user', 'admin'], required: true, default: 'user', index: true },
  active: { type: Boolean, default: true },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
}, { collection: 'Mobile_Users' });

module.exports = mongoose.models.MobileUser ||
  mongoose.model('MobileUser', mobileUserSchema);
