BREAKING CHANGE: auth:legacy scope is being sunset effective 2026-06-15.

All integrations currently using the auth:legacy token flow must migrate to
auth:oauth2 before the cutover date. After June 15, any API call presenting
a legacy token will receive a 401. There will be no grace period extension.

Partners using employees:read through the legacy auth path are affected.

Payment schema v2 is now enforced on all payments:read endpoints. The
amount field is no longer a float, it is now a string representation of
a decimal to avoid precision loss.

Order signing key rotation is scheduled for 2026-06-01. The current key
used by orders:write and auth:token.rotate will be invalidated at 00:00 UTC.

Rate limits on orders:write are dropping from 1000 req/min to 500 req/min.

System maintenance window: 2026-05-24 02:00-04:00 UTC. All endpoints will
return 503 during this window.
