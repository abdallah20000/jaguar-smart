// Copies the static export into the main site's publish folder (site/materials), which Netlify serves
// at jaguarsmart.com/materials. Run after `npm run build`.
import { cpSync, existsSync, rmSync } from "node:fs";
import { fileURLToPath } from "node:url";

const out = fileURLToPath(new URL("../out/", import.meta.url));
const dest = fileURLToPath(new URL("../../site/materials/", import.meta.url));
if (!existsSync(out + "index.html")) throw new Error("Run `npm run build` first.");
rmSync(dest, { recursive: true, force: true });
cpSync(out, dest, { recursive: true });
console.log("Published", out, "->", dest);
