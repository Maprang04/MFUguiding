'use strict';

const axios = require('axios');
const CiscoControllerClient = require(
  '../server/Project/navigation/integrations/cisco-controller-client'
);

function required(name) {
  const value = String(process.env[name] || '').trim();
  if (!value) throw new Error(name + ' is required');
  return value;
}

async function main() {
  const controller = new CiscoControllerClient({
    baseUrl: required('CISCO_CONTROLLER_URL'),
    clientsPath: required('CISCO_CONTROLLER_CLIENTS_PATH'),
    username: process.env.CISCO_CONTROLLER_USERNAME,
    password: process.env.CISCO_CONTROLLER_PASSWORD,
    token: process.env.CISCO_CONTROLLER_TOKEN,
    timeoutMs: Number(process.env.CISCO_CONTROLLER_TIMEOUT_MS || 10000),
    observationIdField: process.env.CISCO_FIELD_OBSERVATION_ID || 'observation_id',
    clientField: process.env.CISCO_FIELD_CLIENT_ID || 'client_id',
    apField: process.env.CISCO_FIELD_AP || 'ap_name',
    rssiField: process.env.CISCO_FIELD_RSSI || 'rssi',
    timestampField: process.env.CISCO_FIELD_TIMESTAMP || 'timestamp'
  });
  const observations = await controller.poll();
  const backendUrl = process.env.CONTROLLER_BACKEND_URL || 'http://127.0.0.1:8097';
  const apiKey = required('CONTROLLER_INGEST_API_KEY');
  const results = [];
  for (const observation of observations) {
    try {
      const response = await axios.post(
        backendUrl + '/api/v1/navigation/controller/observations',
        observation,
        { headers: { 'x-controller-api-key': apiKey } }
      );
      results.push({ status: response.status, accepted: response.data.data.accepted });
    } catch (cause) {
      results.push({
        status: cause.response ? cause.response.status : 503,
        error: cause.response && cause.response.data &&
          cause.response.data.error && cause.response.data.error.code
      });
    }
  }
  console.log(JSON.stringify({
    polled: observations.length,
    accepted: results.filter((item) => item.accepted).length,
    results
  }));
}

main().catch(function (error) {
  console.error(error.message);
  process.exitCode = 1;
});
