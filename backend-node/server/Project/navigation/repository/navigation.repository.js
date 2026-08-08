'use strict';

const NavigationSession = require('../models/navigation-session.model');
const NavigationObservation = require('../models/navigation-observation.model');

function mongooseRepository() {
  return {
    createSession: async function (payload) {
      const created = await NavigationSession.create(payload);
      return created.toObject();
    },
    findSession: function (sessionId) {
      return NavigationSession.findOne({ sessionId }).lean();
    },
    findActiveByUserOrClient: function (userId, clientId) {
      return NavigationSession.findOne({
        status: 'active',
        $or: [{ userId }, { clientId }]
      }).lean();
    },
    findActiveByClient: function (clientId) {
      return NavigationSession.findOne({ clientId, status: 'active' }).lean();
    },
    updateSession: function (sessionId, changes) {
      return NavigationSession.findOneAndUpdate(
        { sessionId },
        { $set: changes },
        { new: true, runValidators: true }
      ).lean();
    },
    createObservation: async function (payload) {
      const created = await NavigationObservation.create(payload);
      return created.toObject();
    },
    observationExists: function (externalObservationId) {
      if (!externalObservationId) return Promise.resolve(false);
      return NavigationObservation.exists({ externalObservationId })
        .then(Boolean);
    },
    listObservations: function (sessionId, limit) {
      return NavigationObservation.find({ sessionId })
        .sort({ timestamp: -1 })
        .limit(limit)
        .lean();
    },
    healthCheck: async function () {
      await NavigationSession.db.db.admin().ping();
      return true;
    }
  };
}

module.exports = mongooseRepository();
module.exports.createRepository = mongooseRepository;
