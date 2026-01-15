/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  env: {
    KAMUSI_API_BASE_URL: process.env.KAMUSI_API_BASE_URL,
  },
};

module.exports = nextConfig;
