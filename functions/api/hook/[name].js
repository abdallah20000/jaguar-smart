// Same-origin relay to the n8n webhooks on the VPS. Some Egyptian mobile networks cannot
// resolve *.srv2112249.hstgr.cloud, so pages call /api/hook/<name> on jaguarsmart.com instead.
const N8N = 'https://n8n-hesb.srv2112249.hstgr.cloud/webhook/';
const ALLOWED = new Set(['all-inbox', 'nile-lead', 'nile-team', 'shahi-team', 'app-ops']);

export async function onRequest({ request, params }) {
  const name = params.name;
  if (!ALLOWED.has(name)) return new Response('Not found', { status: 404 });
  if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 });

  const headers = new Headers();
  const type = request.headers.get('content-type');
  if (type) headers.set('content-type', type);

  const res = await fetch(N8N + name, { method: 'POST', headers, body: await request.arrayBuffer() });
  return new Response(res.body, {
    status: res.status,
    headers: {
      'content-type': res.headers.get('content-type') || 'application/json',
      'cache-control': 'no-store',
    },
  });
}
