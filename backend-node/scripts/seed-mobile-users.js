'use strict';

const mongoose = require('mongoose');
const config = require('../config/config');
const MobileUser = require('../server/Project/mobile-auth/models/mobile-user.model');
const auth = require('../server/Project/mobile-auth/mobile-auth.service');

async function upsert(email, password, role) {
  if (!email || !password) return false;
  const credentials = await auth.createPassword(password);
  await MobileUser.updateOne(
    { email: String(email).trim().toLowerCase() },
    {
      $set: {
        passwordHash: credentials.hash,
        passwordSalt: credentials.salt,
        role,
        active: true,
        updatedAt: new Date()
      },
      $setOnInsert: { createdAt: new Date() }
    },
    { upsert: true }
  );
  console.log(`Seeded ${role}: ${email}`);
  return true;
}

async function main() {
  await mongoose.connect(config.mongoURI, {
    useNewUrlParser: true,
    useUnifiedTopology: true
  });
  const seeded = [
    await upsert(process.env.MOBILE_USER_EMAIL, process.env.MOBILE_USER_PASSWORD, 'user'),
    await upsert(process.env.MOBILE_ADMIN_EMAIL, process.env.MOBILE_ADMIN_PASSWORD, 'admin')
  ].filter(Boolean).length;
  if (!seeded) {
    throw new Error(
      'Set MOBILE_USER_EMAIL/MOBILE_USER_PASSWORD and/or ' +
      'MOBILE_ADMIN_EMAIL/MOBILE_ADMIN_PASSWORD'
    );
  }
}

main()
  .then(() => mongoose.connection.close())
  .catch(async (error) => {
    console.error(error.message);
    await mongoose.connection.close();
    process.exitCode = 1;
  });
