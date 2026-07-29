'use strict';

const auth = require('./mobile-auth.service');

function bearerToken(request) {
  const value = String(request.get('authorization') || '');
  return value.toLowerCase().startsWith('bearer ') ? value.slice(7).trim() : '';
}

async function requireAdmin(request, response, next) {
  try {
    const authenticated = await auth.authenticate(bearerToken(request));
    if (!authenticated) {
      return response.status(401).json({
        error: { code: 'UNAUTHORIZED', message: 'A valid sign-in session is required' }
      });
    }
    if (authenticated.user.role !== 'admin') {
      return response.status(403).json({
        error: { code: 'ADMIN_REQUIRED', message: 'Administrator access is required' }
      });
    }
    request.mobileAuth = authenticated;
    return next();
  } catch (error) {
    return next(error);
  }
}

module.exports = { requireAdmin };
