export default function HomePage() {
  const apiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8000";

  return (
    <section>
      <h1>Connected</h1>
      <p>Admin app is configured and ready.</p>
      <p>
        API base URL: <strong>{apiBaseUrl}</strong>
      </p>
    </section>
  );
}
