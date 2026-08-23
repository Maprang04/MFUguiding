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
      const responseError = cause.response && cause.response.data && cause.response.data.error;
      if (cause.response && cause.response.status === 404 &&
          responseError && responseError.code === 'SESSION_NOT_FOUND') {
        const missing = new Error(responseError.message || 'Positioning session not found');
        missing.code = 'POSITIONING_SESSION_NOT_FOUND';
        missing.status = 404;
        missing.cause = cause;
        throw missing;
      }
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
  configure(snapshot) {
    return this._request({
      method: 'put',
      url: '/configuration',
      data: snapshot
    });
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
  advanceProgress(sessionId, input) {
    return this._request({
      method: 'post',
      url: '/sessions/' + encodeURIComponent(sessionId) + '/progress',
      data: input
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
