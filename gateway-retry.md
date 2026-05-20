Updated payment gateway retry logic. On transient failures the
gateway now returns HTTP 202 instead of 200 with a pending status.
Consumers that check for 200 to confirm a completed transaction
will misread pending payments as failed. Update your status checks.
