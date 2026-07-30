'use strict';

const axios = require('axios');

function field(item, name, fallback) {
  return item[name] !== undefined ? item[name] : item[fallback];
}

class CiscoControllerClient {
  constructor(options) {
    this.options = options;
    this.client = axios.create({
      baseURL: options.baseUrl,
      timeout: options.timeoutMs || 10000,
      auth: options.username
        ? { username: options.username, password: options.password || '' }
        : undefined,
      headers: options.token
        ? { Authorization: 'Bearer ' + options.token }
        : undefined
    });
  }

  async poll() {
    const response = await this.client.get(this.options.clientsPath);
    const body = response.data;
    const items = Array.isArray(body)
      ? body
      : (body.items || body.clients || body.data || []);
    if (!Array.isArray(items)) {
      throw new Error('Cisco clients endpoint did not return an array');
    }
    const now = new Date().toISOString();
    return items.map((item, index) => ({
      observation_id: String(
        field(item, this.options.observationIdField, 'observation_id') ||
        [field(item, this.options.clientField, 'client_id'), now, index].join(':')
      ),
      client_id: String(field(item, this.options.clientField, 'client_id') || ''),
      associated_ap: String(field(item, this.options.apField, 'ap_name') || ''),
      rssi: Number(field(item, this.options.rssiField, 'rssi')),
      timestamp: String(field(item, this.options.timestampField, 'timestamp') || now)
    }));
  }
}

module.exports = CiscoControllerClient;
