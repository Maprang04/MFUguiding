'use strict';

const express = require('express');
const Favorite = require('./models/favorite.model');
const Report = require('./models/report.model');
const Destination = require('../navigation/models/destination.model');
const { requireAuth, requireAdmin } = require('../mobile-auth/mobile-auth.middleware');
const router = express.Router();

function ok(response, data, status) {
  return response.status(status || 200).json({ code: 20000, message: 'Success', data });
}

function fail(response, cause) {
  return response.status(cause.status || 500).json({
    error: {
      code: cause.code || 'MOBILE_CONTENT_ERROR',
      message: cause.message || 'Request failed'
    }
  });
}

function inputError(message) {
  return Object.assign(new Error(message), { status: 400, code: 'INVALID_REQUEST' });
}

router.get('/favorites', requireAuth, async function (request, response) {
  try {
    const favorites = await Favorite.find({ userId: request.mobileAuth.user.id })
      .sort({ createdAt: -1 })
      .lean();
    const ids = favorites.map(function (item) { return item.destinationId; });
    const destinations = await Destination.find({
      destinationId: { $in: ids },
      active: true
    }).lean();
    const byId = Object.fromEntries(destinations.map(function (item) {
      return [item.destinationId, item];
    }));
    return ok(response, {
      items: favorites.filter(function (favorite) {
        return Boolean(byId[favorite.destinationId]);
      }).map(function (favorite) {
        const destination = byId[favorite.destinationId];
        return {
          id: String(favorite._id),
          destination_id: favorite.destinationId,
          label: destination.label,
          floor_id: destination.floorId,
          position: destination.position,
          tag: favorite.tag,
          created_at: favorite.createdAt
        };
      })
    });
  } catch (cause) {
    return fail(response, cause);
  }
});

router.post('/favorites', requireAuth, async function (request, response) {
  try {
    const destinationId = String(request.body.destination_id || '').trim();
    const destination = await Destination.findOne({
      destinationId,
      active: true
    }).lean();
    if (!destination) {
      throw Object.assign(new Error('Destination does not exist'), {
        status: 404,
        code: 'DESTINATION_NOT_FOUND'
      });
    }
    const favorite = await Favorite.findOneAndUpdate(
      { userId: request.mobileAuth.user.id, destinationId },
      {
        $set: { tag: request.body.tag || 'Others' },
        $setOnInsert: { createdAt: new Date() }
      },
      { upsert: true, new: true, runValidators: true }
    ).lean();
    return ok(response, {
      id: String(favorite._id),
      destination_id: destinationId,
      label: destination.label,
      floor_id: destination.floorId,
      position: destination.position,
      tag: favorite.tag
    }, 201);
  } catch (cause) {
    return fail(response, cause);
  }
});

router.delete('/favorites/:destinationId', requireAuth, async function (request, response) {
  try {
    await Favorite.deleteOne({
      userId: request.mobileAuth.user.id,
      destinationId: request.params.destinationId
    });
    return ok(response, { deleted: true });
  } catch (cause) {
    return fail(response, cause);
  }
});

router.post('/reports', requireAuth, async function (request, response) {
  try {
    const type = String(request.body.type || '').trim();
    const location = String(request.body.location || '').trim();
    const description = String(request.body.description || '').trim();
    if (!type || !location || !description) {
      throw inputError('type, location and description are required');
    }
    const created = await Report.create({
      userId: request.mobileAuth.user.id,
      reporterEmail: request.mobileAuth.user.email,
      type,
      location,
      description,
      navigationSessionId: request.body.navigation_session_id || null,
      estimatedPosition: request.body.estimated_position || null
    });
    return ok(response, {
      id: String(created._id),
      status: created.status,
      created_at: created.createdAt
    }, 201);
  } catch (cause) {
    return fail(response, cause);
  }
});

router.get('/reports/mine', requireAuth, async function (request, response) {
  try {
    const items = await Report.find({ userId: request.mobileAuth.user.id })
      .sort({ createdAt: -1 })
      .lean();
    return ok(response, { items });
  } catch (cause) {
    return fail(response, cause);
  }
});

router.get('/admin/reports', requireAdmin, async function (request, response) {
  try {
    const items = await Report.find({}).sort({ createdAt: -1 }).limit(200).lean();
    return ok(response, { items });
  } catch (cause) {
    return fail(response, cause);
  }
});

router.patch('/admin/reports/:id', requireAdmin, async function (request, response) {
  try {
    const allowed = ['approved', 'rejected', 'in_progress', 'resolved'];
    if (!allowed.includes(request.body.status)) throw inputError('Invalid report status');
    const item = await Report.findByIdAndUpdate(
      request.params.id,
      { $set: { status: request.body.status, updatedAt: new Date() } },
      { new: true, runValidators: true }
    ).lean();
    if (!item) {
      throw Object.assign(new Error('Report does not exist'), {
        status: 404,
        code: 'REPORT_NOT_FOUND'
      });
    }
    return ok(response, item);
  } catch (cause) {
    return fail(response, cause);
  }
});

module.exports = router;
