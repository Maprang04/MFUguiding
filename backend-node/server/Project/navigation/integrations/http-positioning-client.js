'use strict';

const axios = require('axios');

class HttpPositioningClient {
  constructor(options) {
    this.client = axios.create({
      baseURL: options.baseUrl,
      timeout: options.timeoutMs
    });
  }

  async _request(config) {
    try {
      const response = await this.client.request(config);
      return response.data;
    } catch (cause) {
      const error = new Error(
        cause.code === 'ECONNABORTED'
          ? 'Positioning service timed out'
          : 'Positioning service unavailable'
      );
      error.code = cause.code === 'ECONNABORTED'
        ? 'POSITIONING_TIMEOUT'
        : 'POSITIONING_UNAVAILABLE';
      error.status = cause.code === 'ECONNABORTED' ? 504 : 503;
      error.cause = cause;
      throw error;
    }
  }

  healthCheck() {
    return this._request({ method: 'get', url: '/health' });
  }
  createSession(input) {
    return this._request({ method: 'post', url: '/sessions', data: input });
  }
  submitObservation(sessionId, observation) {
    return this._request({
      method: 'post',
      url: '/sessions/' + encodeURIComponent(sessionId) + '/observations',
      data: observation
    });
  }
  changeDestination(sessionId, destinationId) {
    return this._request({
      method: 'patch',
      url: '/sessions/' + encodeURIComponent(sessionId) + '/destination',
      data: { destination_id: destinationId }
    });
  }
  getSession(sessionId) {
    return this._request({
      method: 'get',
      url: '/sessions/' + encodeURIComponent(sessionId)
    });
  }
  deleteSession(sessionId) {
    return this._request({
      method: 'delete',
      url: '/sessions/' + encodeURIComponent(sessionId)
    });
  }
}

module.exports = HttpPositioningClient;
