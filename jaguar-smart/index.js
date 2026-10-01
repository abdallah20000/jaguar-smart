// Jaguar Smart Construction - WhatsApp webhook with auto-replies
const express = require('express');

const app = express();
app.use(express.json());

const port = process.env.PORT || 3000;
const verifyToken = process.env.VERIFY_TOKEN;
const whatsappToken = process.env.WHATSAPP_TOKEN;
const graphVersion = process.env.GRAPH_VERSION || 'v21.0';

// Auto-reply menu
const BACK = '\n\nابعت "0" للرجوع للقائمة.';

const MENU = [
  'أهلاً بيك في *Jaguar Smart Construction* 🐆',
  'من التصميم الإنشائي لحد بيت ذكي كامل.',
  '',
  'ابعت رقم الاختيار:',
  '1️⃣ خدماتنا',
  '2️⃣ خطوات الشغل معانا',
  '3️⃣ مشاريعنا',
  '4️⃣ العنوان ومواعيد العمل',
  '5️⃣ احجز استشارة مجانية',
].join('\n');

const REPLIES = {
  '1': [
    '*خدماتنا* 🏗️',
    '- إنشاءات وتشطيبات للفيلات والوحدات السكنية',
    '- إضاءة ذكية ومشاهد جاهزة',
    '- تحكم في التكييف لكل غرفة',
    '- كاميرات وأنظمة أمان وإنتركم فيديو',
    '- أقفال ذكية بالبصمة والكود',
    '- ستائر موتور',
    '- بوابات وجراجات (موتور إيطالي أو صيني)',
    '- صوتيات وسينما منزلية',
    '- شبكات وتحكم مركزي',
    '',
    'كله بعقد واحد ومن تطبيق واحد. بنستخدم KNX و Matter و Zigbee و Home Assistant.',
  ].join('\n') + BACK,
  '2': [
    '*خطواتنا* 📋',
    '1. استشارة ومعاينة للموقع أو الرسومات',
    '2. تصميم هندسي وعرض سعر تفصيلي',
    '3. إنشاءات وتمديدات',
    '4. تركيب وبرمجة واختبار',
    '5. تسليم وتدريب وضمان وصيانة',
    '',
    'وبتعرف السعر النهائي قبل ما نبدأ.',
  ].join('\n') + BACK,
  '3': [
    '*من مشاريعنا* 🏡',
    '- فيلا في الشيخ زايد: تحكم كامل في الإضاءة والستائر والأمان والسينما',
    '- دوبلكس في التجمع الخامس: أقفال ذكية وإنتركم فيديو',
    '- شقة في العاصمة الإدارية: إضاءة وتحكم بالصوت',
    '- فيلا في 6 أكتوبر: بوابة وجراج بموتور إيطالي',
    '- توين فيلا في القاهرة الجديدة: إنشاء وأتمتة من الصفر',
  ].join('\n') + BACK,
  '4': [
    '*العنوان* 📍',
    '57 شارع حسن الشريف، الحي الثامن',
    'مكتب A35، الدور الأول، مدينة نصر، القاهرة',
    'https://www.google.com/maps/search/?api=1&query=57+Hassan+El+Sherif+Street+Nasr+City+Cairo',
    '',
    '*المواعيد* 🕙 من السبت للخميس، 10 الصبح لـ 8 بالليل',
    '📞 +20 111 112 6938',
    '✉️ info@jaguarsmart.com',
  ].join('\n') + BACK,
  '5': [
    'تمام ✅ ابعتلنا في رسالة واحدة:',
    '- الاسم',
    '- مكان المشروع (زايد، أكتوبر، التجمع، مدينة نصر، العاصمة...)',
    '- نوع الوحدة (فيلا، توين هاوس، شقة، مشروع كامل)',
    '- المرحلة (أرض، تحت الإنشاء، تشطيب، ساكن فيها)',
    '',
    'وحد من فريقنا هيكلمك في أقرب وقت.',
  ].join('\n'),
};

function buildReply(text) {
  const key = (text || '').trim();
  return REPLIES[key] || MENU;
}

async function sendText(phoneNumberId, to, body) {
  const res = await fetch(`https://graph.facebook.com/${graphVersion}/${phoneNumberId}/messages`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${whatsappToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ messaging_product: 'whatsapp', to, type: 'text', text: { body } }),
  });
  if (!res.ok) {
    console.error('Send failed:', res.status, await res.text());
  }
}

// Webhook verification
app.get('/', (req, res) => {
  const { 'hub.mode': mode, 'hub.challenge': challenge, 'hub.verify_token': token } = req.query;

  if (mode === 'subscribe' && token === verifyToken) {
    console.log('WEBHOOK VERIFIED');
    res.status(200).send(challenge);
  } else {
    res.status(403).end();
  }
});

// Incoming messages
app.post('/', async (req, res) => {
  // Acknowledge right away so Meta doesn't retry
  res.status(200).end();

  const timestamp = new Date().toISOString().replace('T', ' ').slice(0, 19);
  console.log(`\nWebhook received ${timestamp}`);

  const value = req.body?.entry?.[0]?.changes?.[0]?.value;
  const message = value?.messages?.[0];
  if (!message) return; // status updates (sent/delivered/read)

  const from = message.from;
  const phoneNumberId = value.metadata.phone_number_id;
  const text = message.type === 'text' ? message.text.body : '';
  console.log(`From ${from}: ${text || `[${message.type}]`}`);

  try {
    await sendText(phoneNumberId, from, buildReply(text));
  } catch (err) {
    console.error('Error replying:', err);
  }
});

app.listen(port, () => {
  console.log(`\nJaguar Smart bot listening on port ${port}\n`);
});
