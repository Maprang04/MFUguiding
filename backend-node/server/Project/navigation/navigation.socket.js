'use strict';

const events = require('./navigation.events');

module.exports = function registerNavigationSocket(io, socket) {
  socket.on('navigation:join', function (payload, callback) {
    const sessionId = payload && String(payload.session_id || '').trim();
    if (!sessionId) {
      if (typeof callback === 'function') callback({ ok: false, error: 'session_id is required' });
      return;
    }
    socket.join('navigation:' + sessionId);
    if (typeof callback === 'function') callback({ ok: true, session_id: sessionId });
  });

  if (!events.__navigationIoBound) {
    [
      'navigation:position',
      'navigation:roaming',
      'navigation:route',
      'navigation:completed',
      'navigation:cancelled'
    ].forEach(function (eventName) {
      events.on(eventName, function (event) {
        io.to('navigation:' + event.sessionId).emit(eventName, event.data);
      });
    });
    events.__navigationIoBound = true;
  }
};
