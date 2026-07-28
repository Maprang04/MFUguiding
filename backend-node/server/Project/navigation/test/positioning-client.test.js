'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const config = require('../config/navigation.config');
const MockPositioningClient = require('../integrations/mock-positioning-client');
const createPositioningClient = require('../integrations/positioning-client.factory');

test('factory creates mock positioning client by default', function () {
  const client = createPositioningClient({ positioningMode: 'mock' });
  assert.ok(client instanceof MockPositioningClient);
});

test('mock positioning keeps AP candidates separate until confirmation', async function () {
  const client = new MockPositioningClient(config);
  await client.createSession({
    session_id: 'nav-test',
    client_id: 'device-1',
    destination_id: 'room_2'
  });

  const initial = await client.submitObservation('nav-test', {
    associated_ap: 'AP3',
    rssi: -62
  });
  const candidate = await client.submitObservation('nav-test', {
    associated_ap: 'AP2',
    rssi: -73
  });

  assert.equal(initial.confirmed_ap, 'AP3');
  assert.equal(candidate.confirmed_ap, 'AP3');
  assert.equal(candidate.candidate_ap, 'AP2');
  assert.equal(candidate.candidate_count, 1);
  assert.equal(candidate.roaming_confirmed, false);
});
