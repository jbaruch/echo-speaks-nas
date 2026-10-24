# Review source, Node image, and npm pins monthly and when Amazon changes login.
FROM node:24-bookworm-slim@sha256:55fb5f5a527ea2c5c4a95f963e48ef90aa38c7b346054fdc8ee9957a2b55d205
WORKDIR /app
ADD --checksum=sha256:947fe6cd3610895dcd01efb89f17ee95042e3ec647c8701aa5167d1f7181dd17 https://codeload.github.com/bloodtick/echo-whispers-server/tar.gz/59d3a99e73ce35b929aeec645bfb8a7e49884ad5 /tmp/source.tar.gz
RUN tar -xzf /tmp/source.tar.gz --strip-components=1 -C /app && rm /tmp/source.tar.gz
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts --no-audit --no-fund
# Echo Speaks opens /config for its login-service management link.
RUN node -e "const fs=require('node:fs');const p='server.js';const s=fs.readFileSync(p,'utf8');const a=\"app.get('/', (req, res) => {\";if(s.split(a).length!==2)throw Error('Upstream UI route changed');fs.writeFileSync(p,s.replace(a,\"app.get(['/', '/config'], (req, res) => {\"));" \
    && node --check server.js \
    && node -e "const fs=require('node:fs');const p='server.js';const s=fs.readFileSync(p,'utf8');const a=\"logger: (msg) => console.log('[ALEXA]', msg)\";if(s.split(a).length!==2)throw Error('Upstream logger changed');fs.writeFileSync(p,s.replace(a,'logger: undefined'));" \
    && chown -R node:node /app
USER node
EXPOSE 8091 8092
CMD ["sh", "-c", "umask 077; exec node server.js"]
