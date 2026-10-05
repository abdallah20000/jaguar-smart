// Secret links to guest orders/quotes kept in this browser, so they can be claimed after sign-in.
const KEY = "mat_tokens";
export type SavedToken = { kind: "order" | "quote"; token: string; number: string; at: string };
export function saveToken(t: SavedToken) {
  try {
    const all: SavedToken[] = JSON.parse(localStorage.getItem(KEY) || "[]");
    localStorage.setItem(KEY, JSON.stringify([t, ...all.filter((x) => x.token !== t.token)].slice(0, 50)));
  } catch { /* storage blocked: the link is still shown on screen */ }
}
export function savedTokens(): SavedToken[] {
  try { return JSON.parse(localStorage.getItem(KEY) || "[]"); } catch { return []; }
}
