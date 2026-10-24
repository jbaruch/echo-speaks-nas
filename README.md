# Echo Speaks cookie server on the NAS

Runs the community [Echo Whispers Server](https://github.com/bloodtick/echo-whispers-server),
using its Echo Speaks compatibility mode. Existing Hubitat Echo Speaks devices,
actions, and rules continue using the existing app. This replaces its cookie server.

The stock 2.8.0 image still bundles the old Amazon login proxy. The
[October 24 report](https://community.hubitat.com/t/release-echo-speaks-v4/68843/2760)
describes the same `/ax/claim` failure. Echo Whispers was introduced in
[post 2618](https://community.hubitat.com/t/release-echo-speaks-v4/68843/2618), with
automatic refresh and Echo Speaks refresh compatibility confirmed by its author in
[post 2656](https://community.hubitat.com/t/release-echo-speaks-v4/68843/2656).
The general [Docker migration guide](https://community.hubitat.com/t/guide-echo-speaks-server-on-docker-or-without/111186)
documents persistent storage, local callbacks, and the Hubitat server reset procedure.

This image uses pinned upstream source and a locked npm dependency tree with
`alexa-cookie2` 5.0.6. One UI route alias makes Hubitat's `/config` link work.
The upstream Alexa logger is disabled because it prints authentication cookies
and request headers. Server lifecycle and Hubitat callback diagnostics remain.
Review the source commit, Node image digest, and npm pins monthly and whenever
Amazon changes its login flow. Rebuild and repeat the validation below after updates.

## Deploy

Copy this directory to `/volume1/docker/echo-speaks` on `nas`.
Copy `.env.example` to `.env` and set `NAS_IP` to the LAN address.
Create `data` owned by the image's `node` user (UID/GID 1000), mode 700.
Run `docker compose up -d --build` from that directory.

The web UI is `http://NAS_IP:8091/`; the temporary Amazon login proxy uses
`http://NAS_IP:8092/`. Both ports bind to the selected NAS address. Persistent
settings and Amazon registration data live in `data/config.json` with mode 600.
Keep `data` and `.env` out of git. Back up `data` privately.

## Configure

Open the UI, enable Hubitat compatibility, and set the local callback URL to
`http://HUB_IP/apps/api/APP_ID/receiveData?access_token=TOKEN` using the existing
Echo Speaks app token. Set the server URL to `http://NAS_IP:8091/` and the
Echo Speaks compatibility version to `2.8.0` (server protocol version).
Keep the existing Amazon region settings. Save settings.

In Hubitat, use Manage Cookie Login Service → Reset Options → Reset Service
Data. Return to the app, disable Deploy server to Heroku, and complete local
server setup. Preserve the installed app and its devices.

Click Amazon Login in the NAS UI and complete login/MFA in a private browser
window. After login, use Send Info and Send Cookie if automatic sync has not
already completed. Confirm the Hubitat app names the NAS as its server.

## Validate

- `docker compose ps` reports healthy; `/health` returns HTTP 200.
- `/config` opens the same UI as `/`.
- Both GET and POST `/wakeup` return plain text `OK`, as Echo Speaks expects.
- The login proxy reaches Amazon's form without a missing-route error.
- Complete Amazon login; confirm cookie, CSRF, registration, and refresh token
  are present without printing their values.
- Confirm Hubitat `authValid`, NAS server address, existing child-device count,
  and polling schedules. A server health check alone does not prove Amazon login.
- Restart the container and confirm authentication survives.
- Refresh the cookie from the NAS UI and confirm a fresh callback reaches Hubitat.

## Rollback and Heroku retirement

Keep the old Heroku server available until login, restart persistence, and refresh
have passed. To revert, restore the previous Hubitat service settings/callback and
stop this container with `docker compose stop`. The private pre-migration backup
on the NAS records the previous configuration. `docker compose down` leaves
the bind-mounted data intact. Delete the Heroku app only after successful cutover;
that is a separate account/billing action.

## Installation record — October 24, 2026

Deployed on `nas` (`192.168.10.32`) at `/volume1/docker/echo-speaks` as
container `echo-speaks`. The existing main-hub app is instance 68 on
`192.168.30.15`; all 16 existing child devices and both Actions remain installed.
Hubitat's service settings were reset through the UI, Heroku was disabled,
the local callback returned HTTP 200, and the NAS address was read back from
the app's server state. Done was pressed to commit the configuration.

Passed: image build, source syntax check, locked `alexa-cookie2` 5.0.6 with
no nested older copy, healthy container, `/health`, `/config`, and both
`/wakeup` methods. Amazon login completed at 23:48 UTC. Hubitat accepted the
cookie and reported `authValid: true`. A refresh-token renewal returned HTTP
200, changed the cookie without re-registering the device, and delivered it
to Hubitat successfully. After a container restart, all saved authentication
fields survived and authenticated device discovery returned 33 Amazon devices.
The existing Hubitat app still has 16 child devices and both Actions, with
polling and health-check schedules active. Heroku has not been deleted.

An immediate Amazon error page occurred before any credential submission on
the NAS IP. Request-header inspection showed NAS web-interface cookies being
forwarded to Amazon; this is a possible contributor, not a proven root cause.
A fresh proxy session completed successfully through a temporary SSH tunnel on the
operator's Mac, isolating the login from NAS browser cookies:

```sh
ssh -N -o ExitOnForwardFailure=yes \
  -L 127.0.0.1:18091:192.168.10.32:8091 \
  -L 127.0.0.1:8092:192.168.10.32:8092 nas
```

Start login by POSTing `/api/login/start` through port 18091 so the proxy
advertises `127.0.0.1`, then open `http://127.0.0.1:8092/` in a private window.
The tunnel is needed only for this manual login. The persistent Hubitat server
address and callback stay on the NAS/hub LAN addresses. The temporary tunnel
was closed after login and the authenticated restart/refresh checks passed.
Subsequent manual logins may require recreating it; regular operation does not.
