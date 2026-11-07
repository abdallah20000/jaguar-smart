# تسليم: موظفين الـ AI + تنضيف n8n (8 نوفمبر 2026)

اتعمل من جلسة Claude التانية (شات "موظفين الـ AI"). اقرا الملف ده قبل ما تلمس n8n أو شاشة «العمليات» في /app.

## 1) n8n: كله على سيرفر Hostinger دلوقتي
- السيرفر: `https://n8n-hesb.srv2112249.hstgr.cloud`. n8n Cloud (`jaguarabdallah.app.n8n.cloud`) **واقف**، لأن حصة التشغيل خلصت والـ production مش بيشتغل. مفيش حاجة تتوجه عليه.
- كل الـ relay في `functions/api/hook/[name].js` بيروح للسيرفر، ومفيش استثناء لـ `app-ops`.
- **الشغال 9 workflows بدل 18** (اتجمعوا بالوظيفة، والأصول اتأرشفت مش اتمسحت):

| الـ workflow (ID) | جواه | webhooks / triggers |
|---|---|---|
| واتساب البيزنس (Meta) `YvJSgjmvZxs3VKiA` | وكيل واتساب Jaguar + الرد اليدوي + كود الدخول | WhatsApp trigger, `jaguar-inbox-reply`, `app-otp-1b08231160f5186138f77da1` |
| واتساب رقمك الشخصي (Green) `Umnpc2YC6MnBAK6j` | السجل الرقمي + جروبات الحسابات + ملخص جروب Tuya + تنبيهات Claude | Green trigger, `accounting-groups`, `claude-alert`, cron 23:30 |
| API التطبيق والمواقع `kElWgVoeQ07IDVAF` | اللوحة الموحدة + العمليات + منيو شاهي + ليدز Nile | `all-inbox`, `app-ops`, `shahi-asset`, `shahi-asset-upload`, `nile-lead` |
| موظفين الـ AI — Jaguar `4Ze3S9hmIEklk3kP` | المحتوى + صياد العملاء + المنافسين + ملخص الليل | سبت 10، كل يوم 8، 8:15 (ماعدا الجمعة)، حد 11، 21:00، فورم `jaguar-leads` |
| موظف التستنج `lzyVmQ1h2buUrrbA` | Error Trigger + فحص يومي | 9:30 الصبح |
| أدوات يدوية `fOgihnyjcLuoR1Of` | تفريغ يوتيوب + تصنيف الأرقام | فورمات |
| شاهي — لوحة الفريق `MswB6BqmwosbtpY8` | زي ما هي | `shahi-team` |
| Nile — لوحة الفريق `CmHof2EBo9YsnO8i` | زي ما هي | `nile-team` |
| متابعة WeChat `e2JKBdoVqX7L5qud` | زي ما هي | `wechat-in` |

- **كل الـ workflows الشغالة `settings.errorWorkflow = lzyVmQ1h2buUrrbA`**. أي workflow جديد لازم ياخد نفس الإعداد ده، عشان التستر يمسكه.
- لو عدّلت workflow شغال، انشر النسخة بعد ما تعدّل. التستر بيتأكد إن مفيش حاجة واقفة.

## 2) جداول n8n (Data tables على السيرفر)
- `app_ops` (`TvbUiDjpAcZhT7PC`): كل اللي الموظفين عملوه.
  الأعمدة: `kind` (report | approval)، `business`، `agent` (content | leads | competitors | summary | tester | claude)، `title`، `body`، `link` (wa.me للرسايل)، `status` (pending | approved | rejected | done)، `review` (ملاحظة المراجع)، `ref_table`، `ref_id`، `decided_at`، `day` (yyyy-MM-dd بتوقيت القاهرة).
- `system_errors` (`JmcJARH7YkLrh7h1`): كل وقعة (`workflow`، `node`، `message`، `execution_id`، `at`).

## 3) شاشة «العمليات» في /app (ليها كود في `site/app/index.html`)
- `POST /api/hook/app-ops` form-encoded:
  - `{token, action:'list'}` يرجع `{items[], stats:{pending, today, approved_today}}`.
  - `{token, action:'decide', id, decision: approved|rejected}`.
- الـ token هو access_token بتاع Supabase، والسيرفر بيتأكد بـ `rpc/app_is_owner` (للمالك بس).
- لما يوافق على رسالة عميل، التطبيق بيفتح `link` (واتساب بالرسالة جاهزة) وهو اللي بيدوس إرسال. **مفيش رسالة بتطلع لعميل من غير موافقته.** متغيرش القاعدة دي.
- التحديث: عند الفتح، ولما التطبيق يرجع للشاشة، وكل 15 دقيقة.

## 4) موظف التستنج: بيفحص إيه كل يوم 9:30
10 صفحات (jaguarsmart.com، /app، /crm، /materials، /tuya-suez، /shahi، /shahi/menu، /nile-digital-solution، /cobra-egypt، aixegypt.com)، و4 APIs (لازم ترد 401 من غير توكن)، وSupabase بتاع Jaguar وAIX، ومفتاح Gemini، وإن البوست وصياد العملاء وملخص امبارح اتعملوا، والأخطاء في آخر 24 ساعة.
التقرير بيتسجل في `app_ops` (agent=tester)، ولو فيه ❌ بيبعت واتساب لعبدالله.
**لو أضفت صفحة أو API جديد، ضيفه في كود "افحص كل حاجة" في workflow التستر.**

## 5) ملفات مرجعية في الـ repo
`n8n/ai-employees/`: patch الموظفين + الـ API + التستر (JSON).

## 6) الجاي (مقترح، محتاج موافقة عبدالله)
- كارت في الرئيسية فيه **آخر تقرير فحص** (🟢/🔴) من `app_ops` (agent=tester).
- **شاشة المصاريف والحسابات**: إجمالي اشتراكات السيستم (Hostinger VPS، Green API، Meta WhatsApp، Gemini، Supadata، الدومينات) + مصاريف/دخل كل شركة من الـ CRM. **الأرقام لازم تيجي من عبدالله أو من الفواتير الحقيقية، ممنوع أي رقم من دماغك.**
- لما تضيف أي workflow أو صفحة: حدّث الجدول اللي فوق في الملف ده.
