'use strict';

const mongoose = require('mongoose');

const databaseName = String(
  process.env.INDOOR_NAVIGATION_DB || 'indoor_navigation'
).trim();

// Reuse the same MongoDB client/cluster as the legacy backend, but keep all
// indoor-navigation collections in their own database.
module.exports = mongoose.connection.useDb(databaseName, { useCache: true });
