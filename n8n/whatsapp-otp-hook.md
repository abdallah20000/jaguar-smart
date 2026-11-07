# Sign in to the app (/app) with a phone number and a WhatsApp code

How it works: a team member signs up once with email and password. Inside the app they link their
phone number (Supabase sends a code, they type it). After that they can sign in with phone + code.
Supabase makes the code and calls our n8n webhook (Send SMS hook); n8n sends the code from the
WhatsApp bot number. The main bot workflow is not touched.

## 1. n8n on Hostinger

1. Import `whatsapp-otp-hook.workflow.json` as a new workflow. Do not edit the main bot.
2. Node «ابعت الكود على واتساب»: choose the same WhatsApp credential the bot uses, and set
   `phoneNumberId` to the bot's phone number ID (replace `BOT_PHONE_NUMBER_ID`).
3. Production webhook URL: `https://<n8n host>/webhook/app-otp-1b08231160f5186138f77da1`.
4. Leave it inactive until step 2 gives you the secret.

## 2. Supabase (project jaguar-smart)

1. Authentication → Sign In / Providers → **Phone**: enable it. With a Send SMS hook no SMS
   provider credentials are needed.
2. Authentication → Hooks → **Send SMS hook** → HTTPS, URL from step 1.3. Supabase shows a secret
   `v1,whsec_…`. Paste it into `HOOK_SECRET` in the node «تحقق من التوقيع», save, then activate the
   workflow.
3. Optional: Phone OTP expiry 300 s and length 6 (Authentication → Providers → Phone).

## 3. The 24-hour WhatsApp rule

WhatsApp only allows free-text messages to people who wrote to the business number in the last 24
hours. Two ways around it:

- Now: the app shows «افتح واتساب وابعتلنا رسالة» when a code fails. Set `BOT_WA` in
  `site/app/index.html` to the bot number (digits only) so that button appears.
- Better: create an **Authentication** message template in Meta Business Manager (category
  Authentication, one code parameter). Once approved, switch the WhatsApp node to send that
  template, and the 24-hour rule no longer applies.

## Security notes

- The webhook only acts on requests with a valid Standard Webhooks signature less than 5 minutes
  old. Without `HOOK_SECRET` it rejects everything.
- Phone sign-in uses `shouldCreateUser: false`, so a phone number that is not linked to an
  existing account cannot create one.
- Team access still comes from `team_members` / `shahi_staff`, exactly as with email sign-in.
