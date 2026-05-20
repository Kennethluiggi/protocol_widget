We are transitioning away from the older authentication pathway.
Clients still relying on the original token issuance flow will need
to move to the new one before Q3. The old flow will stop accepting
requests silently — no error, just dropped connections.
