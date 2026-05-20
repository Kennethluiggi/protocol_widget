billing: update invoice generation pipeline

Subscription renewal flow has been updated. Invoice line items now include
a new required field: tax_jurisdiction. Partners consuming billing webhooks
must update their payload parsers. Payment processing cutover is 2026-06-10.
