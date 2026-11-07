# jaguarsmart.com — ملاحظات لـ Claude

- الموقع ملفات ثابتة في `site/` على Cloudflare Pages (أي push على main بيتنشر على طول). الـ relay للـ n8n في `functions/api/hook/[name].js`.
- n8n كله على سيرفر Hostinger (`n8n-hesb.srv2112249.hstgr.cloud`)، وn8n Cloud واقف.
- **قبل ما تلمس n8n أو شاشة «العمليات» أو موظفين الـ AI، اقرا `docs/HANDOFF-ai-employees.md`.** فيه خريطة الـ 9 workflows، والجداول، وقواعد الموافقة، وموظف التستنج.
- قاعدة ثابتة: مفيش رسالة أو بوست يطلع لعميل من غير موافقة عبدالله من التطبيق.
- أي workflow جديد على السيرفر: `settings.errorWorkflow = lzyVmQ1h2buUrrbA` (موظف التستنج).
- عبدالله عايز الكلام بالمصري ومن غير مقدمات.
