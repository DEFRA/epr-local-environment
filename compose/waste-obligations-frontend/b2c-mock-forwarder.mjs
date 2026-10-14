// Used by compose.b2cmock.yml. waste-obligations-frontend builds its authorize URL (visited by the
// browser) and its token URL (called from this container) from the same AZURE_AD_B2C_INSTANCE, so
// the instance has to resolve both in the browser and in here. The browser reaches the mock at
// https://localhost:8443; this forwards the container's own localhost:8443 to b2c-mock:8443 so the
// token call reaches it too. TLS passes straight through: the mock's certificate covers localhost.

import net from 'node:net'

function forward(client) {
  const upstream = net.connect(8443, 'b2c-mock')
  client.pipe(upstream).pipe(client)
  client.on('error', () => upstream.destroy())
  upstream.on('error', () => client.destroy())
}

// localhost resolves to ::1 first in the Alpine image, so listen on both loopback addresses.
for (const host of ['127.0.0.1', '::1']) net.createServer(forward).listen(8443, host)
