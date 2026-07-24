'use strict';

const config = require('../config/navigation.config');
const MockPositioningClient = require('./mock-positioning-client');
const HttpPositioningClient = require('./http-positioning-client');

function createPositioningClient(overrides) {
  const options = Object.assign({}, config, overrides || {});
  if (options.positioningMode === 'http') {
    return new HttpPositioningClient({
      baseUrl: options.positioningServiceUrl,
      timeoutMs: options.positioningTimeoutMs
    });
  }
  return new MockPositioningClient(options);
}

module.exports = createPositioningClient;
