Auth pathway notice - 2026-05-19 20:38

We are transitioning away from the older authentication pathway.
Clients still relying on the original token issuance flow will need
to move to the new one before Q3. The old flow will stop accepting
requests silently — no error, just dropped connections.

Partners using the employee data sync through legacy auth must also
update their integration before the cutover date.
