# Jaguar Smart Construction

[![Netlify Status](https://api.netlify.com/api/v1/badges/240ecb61-53c3-40cc-9ba4-522f3c3781a3/deploy-status)](https://app.netlify.com/projects/jaguarsmart/deploys)

Website and WhatsApp bot for [jaguarsmart.com](https://jaguarsmart.com).

- `site/` – the website, deployed by Netlify (base and publish directory: `site`, no build command)
- `jaguar-smart/` – WhatsApp auto-reply webhook (Express). Run with `npm install && npm start`, setting `VERIFY_TOKEN` and `WHATSAPP_TOKEN`.
