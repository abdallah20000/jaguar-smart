import type { NextConfig } from "next";
import createNextIntlPlugin from "next-intl/plugin";

const withNextIntl = createNextIntlPlugin("./src/i18n/request.ts");

// The store is exported as static files and served by the main site's Netlify deploy
// under jaguarsmart.com/materials (see scripts/publish-to-site.mjs).
const nextConfig: NextConfig = {
  output: "export",
  basePath: "/materials",
  trailingSlash: true,
  images: { unoptimized: true },
  reactStrictMode: true,
};

export default withNextIntl(nextConfig);
