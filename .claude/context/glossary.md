# Domain Glossary

<!--
═══════════════════════════════════════════════════════════════════════════════
WHAT THIS FILE IS

The terms in this codebase that don't mean what they sound like — or that
the agent might confuse with a different concept from training data.

WHY THIS FILE EXISTS

LLMs are trained on the statistical center of the world. When they see
"Customer," they think Salesforce-shape Customer. When they see "Site,"
they think website. Your domain might mean something specific:
  - "Customer" = household with one shared internet connection
  - "Site" = physical antenna tower location

Without this glossary, the agent will write code that subtly misuses your
own vocabulary, and you won't notice until something breaks.

WHEN TO ADD AN ENTRY

Every time you find yourself correcting the agent's interpretation of a
domain term. If you correct it once, others will need to be corrected too.
═══════════════════════════════════════════════════════════════════════════════
-->

## Core entities

**Customer** — A household subscribed to internet service. Has exactly one billing account, one or more devices, and one service address. Distinct from `User`, which is a person who can log into the customer portal (a Customer can have multiple Users).

**User** — A login identity that belongs to one Customer. Has email, password (hashed), and optional admin flag. **Not** a synonym for "Customer."

**Site** — A physical antenna tower location. Has GPS coordinates, mast height, and one or more APs. **Not** a website. **Not** a customer's home.

**AP (Access Point)** — A wireless transmitter at a Site, serving N customers. An AP belongs to exactly one Site.

**PTP (Point-to-Point)** — A backhaul wireless link between two Sites. Different from AP — PTPs serve no customers, only carry backhaul traffic.

**Station** — A customer-side wireless receiver. One Station per Customer device.

## Status terms

**Active** — Has a paid invoice in the last 60 days AND device is powered on.
*Not* the same as "online" — a customer can be Active but offline if their power is out.

**Online** — Device responded to last heartbeat (within 5 minutes).
*Not* the same as Active — see above.

**Suspended** — Customer has unpaid invoice >60 days. Service is throttled to a captive portal. **Not** the same as deleted.

**Soft-deleted** — `deleted_at IS NOT NULL` in DB. Data preserved, queries filter it out. Different from a "hard delete" which we never do for user data.

## Money terms

**Invoice** — A bill issued for one billing period. Has `amount_cents` (integer; never use floats for money).

**Payment** — A successful charge against an Invoice via MercadoPago. An Invoice can have multiple Payments (partial pays).

**Debt** — `SUM(invoice.amount_cents) - SUM(payment.amount_cents)` for invoices older than 30 days.

**Aging bucket** — Invoice classified by days overdue: 0-30, 31-60, 61-90, 90+. Used for collections workflows.

## File-naming conventions

**Migrations** — Filename pattern: `YYYY_MM_DD_HHMMSS_description.sql`. Never edit a migration after it's been run in production. Add a new migration to fix issues.

**Routes** — One file per resource at `src/routes/<resource>.py`. The file exports a `router` object. Do not split a single resource across multiple files.

**Tests** — Mirror the source structure: `src/services/payments.py` → `tests/services/test_payments.py`.

## Common confusions to call out explicitly

- "Site" means **antenna tower**, never "website"
- "Customer" means **household**, never the person logging in (that's "User")
- "Active" means **billed and paid**, not "currently online"
- "Hot site" is a specific operational term for a tower with >80% AP utilization, not a marketing-funnel metaphor
- "Outage" requires a customer-facing impact. A device losing connection alone is a "device offline" event, not an outage.

<!--
═══════════════════════════════════════════════════════════════════════════════
TIPS FOR MAINTAINING THIS FILE

- Add an entry the first time the AI gets a term wrong. Don't wait for it
  to happen three times.
- Keep entries to 1-3 sentences. This file is reference, not documentation.
- When two terms are commonly confused (Site vs. Website, Customer vs.
  User), say so explicitly in the "Common confusions" section.
═══════════════════════════════════════════════════════════════════════════════
-->
