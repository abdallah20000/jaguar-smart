import next from "eslint-config-next/core-web-vitals";
import ts from "eslint-config-next/typescript";

const config = [
  ...next,
  ...ts,
  // header/footer links go to the main jaguarsmart.com pages, outside this app's /materials basePath,
  // so they must be plain <a> tags, not next/link
  { rules: { "@next/next/no-html-link-for-pages": "off" } },
  { ignores: ["out/**", ".next/**", "scripts/**"] },
];
export default config;
