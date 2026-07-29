'use strict';

const crypto = require('crypto');
const { promisify } = require('util');
const MobileUser = require('./models/mobile-user.model');
const MobileSession = require('./models/mobile-session.model');

const scrypt = promisify(crypto.scrypt);
const SESSION_HOURS = Number(process.env.MOBILE_SESSION_HOURS || 24);

function cleanEmail(value) {
  return String(value || '').trim().toLowerCase();
}

function tokenHash(token) {
  return crypto.createHash('sha256').update(String(token)).digest('hex');
}

async function hashPassword(password, salt) {
  const derived = await scrypt(String(password), salt, 64);
  return Buffer.from(derived).toString('hex');
}

async function createPassword(password) {
  if (String(password || '').length < 8) {
    throw Object.assign(new Error('Password must contain at least 8 characters'), {
      status: 400,
      code: 'WEAK_PASSWORD'
    });
  }
  const salt = crypto.randomBytes(16).toString('hex');
  return { salt, hash: await hashPassword(password, salt) };
}

async function verifyPassword(password, user) {
  const actual = Buffer.from(await hashPassword(password, user.passwordSalt), 'hex');
  const expected = Buffer.from(user.passwordHash, 'hex');
  return actual.length === expected.length && crypto.timingSafeEqual(actual, expected);
}

function publicUser(user) {
  return {
    id: String(user._id),
    email: user.email,
    role: user.role
  };
}

async function login(email, password) {
  const normalizedEmail = cleanEmail(email);
  if (!normalizedEmail || !password) {
    throw Object.assign(new Error('Email and password are required'), {
      status: 400,
      code: 'INVALID_REQUEST'
    });
  }
  const user = await MobileUser.findOne({ email: normalizedEmail, active: true });
  if (!user || !await verifyPassword(password, user)) {
    throw Object.assign(new Error('Email or password is incorrect'), {
      status: 401,
      code: 'INVALID_CREDENTIALS'
    });
  }
  const token = crypto.randomBytes(32).toString('base64url');
  const expiresAt = new Date(Date.now() + SESSION_HOURS * 60 * 60 * 1000);
  await MobileSession.create({
    tokenHash: tokenHash(token),
    userId: user._id,
    expiresAt
  });
  return { token, expires_at: expiresAt.toISOString(), user: publicUser(user) };
}

async function authenticate(token) {
  if (!token) return null;
  const session = await MobileSession.findOne({
    tokenHash: tokenHash(token),
    revokedAt: null,
    expiresAt: { $gt: new Date() }
  }).lean();
  if (!session) return null;
  const user = await MobileUser.findOne({ _id: session.userId, active: true }).lean();
  return user ? { session, user: publicUser(user) } : null;
}

async function logout(token) {
  if (token) {
    await MobileSession.updateOne(
      { tokenHash: tokenHash(token), revokedAt: null },
      { $set: { revokedAt: new Date() } }
    );
  }
  return { logged_out: true };
}

module.exports = {
  authenticate,
  createPassword,
  login,
  logout
};
