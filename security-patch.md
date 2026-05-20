security: patch CVE-2026-1042 in token validation layer

A vulnerability in the JWT validation middleware allowed malformed tokens
to bypass signature verification in edge cases. Partners using auth:legacy
or auth:token.rotate should rotate their credentials as a precaution.
Patch is live. No action required unless credentials were exposed.
