/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // KAMUSI_API_BASE_URL is deliberately NOT listed under `env`. That block
  // inlines a value at build time and ships it to the browser, which both
  // prevents configuring the API URL per environment from one build and
  // exposes an internal address. It is read by the route handlers in
  // app/api/* from process.env at request time instead.
};

module.exports = nextConfig;
