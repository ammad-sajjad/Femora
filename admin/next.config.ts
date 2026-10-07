import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Bundled rather than loaded at runtime: firebase-admin requires jose v6, which is ESM-only, and
  // Vercel's runtime refuses that require() from an external package.
  transpilePackages: ["firebase-admin", "jwks-rsa", "jose"],
  cacheComponents: true,
  partialPrefetching: true,
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
