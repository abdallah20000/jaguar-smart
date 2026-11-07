# موظفين الـ AI (n8n على سيرفر Hostinger)

- `employees.patch.json` — بيجمع المحتوى + المنافسين + صياد العملاء + ملخص الليل في workflow واحد، وكله بيكتب في جدول `app_ops`.
- `app-ops-api.workflow.json` — الـ API اللي شاشة "العمليات" في /app بتكلمه (`/api/hook/app-ops`): يعرض ويوافق/يرفض، للمالك بس.
- `tester.workflow.json` — موظف التستنج: Error Trigger يسجل أي وقعة في `system_errors`، وفحص يومي 9:30 الصبح للمواقع والـ APIs وSupabase وGemini والموظفين، والتقرير في التطبيق + واتساب لو فيه مشكلة.
