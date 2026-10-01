# Jaguar Smart Construction

[![Netlify Status](https://api.netlify.com/api/v1/badges/240ecb61-53c3-40cc-9ba4-522f3c3781a3/deploy-status)](https://app.netlify.com/projects/jaguarsmart/deploys)

Website and WhatsApp bot for [jaguarsmart.com](https://jaguarsmart.com).

- `site/` – deployed by Netlify (base and publish directory: `site`, no build command)
  - `site/index.html` – jaguarsmart.com
  - `site/tuya-suez/` – Tuya Suez landing page (jaguarsmart.com/tuya-suez/) and the team system:
    `crm.html` (login, CRM, products, quotations + PDF), `inventory.html`, `installs.html`
- `supabase/migrations/` – database schema, roles and RLS for the team system (Supabase project `jaguar-smart`).
  `002_delete_functions.sql` must be run once by hand in the Supabase SQL editor.
- `jaguar-smart/` – WhatsApp auto-reply webhook (Express). Run with `npm install && npm start`, setting `VERIFY_TOKEN` and `WHATSAPP_TOKEN`.
