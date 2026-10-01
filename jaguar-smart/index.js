// Jaguar Smart - WhatsApp webhook with auto-replies
const express = require('express');

const app = express();
app.use(express.json());

const port = process.env.PORT || 3000;
const verifyToken = process.env.VERIFY_TOKEN;
const whatsappToken = process.env.WHATSAPP_TOKEN;
const graphVersion = process.env.GRAPH_VERSION || 'v21.0';

// Auto-reply menu
const MENU = [
  'أهلاً بيك في *Jaguar Smart* 🐆',
  '',
  'ابعت رقم الاختيار:',
  '1️⃣ المنتجات',
  '2️⃣ الأسعار والعروض',
  '3️⃣ مواعيد العمل والعنوان',
  '4️⃣ كلّم خدمة العملاء',
].join('\n');

const REPLIES = {
  '1': 'منتجاتنا 📦\n- منتج 1\n- منتج 2\n- منتج 3\n\nابعت "0" للرجوع للقائمة.',
  '2': 'العروض الحالية 🔥\n- خصم 10% على أول طلب\n\nابعت "0" للرجوع للقائمة.',
  '3': 'مواعيدنا 🕘\nمن السبت للخميس، 10 الصبح لـ 10 بالليل\n📍 العنوان: ...\n\nابعت "0" للرجوع للقائمة.',
  '4': 'تمام ✅ حد من خدمة العملاء هيكلمك في أقرب وقت.',
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
