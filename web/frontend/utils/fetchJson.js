const FALLBACK_ERROR = "Couldn't load data from Shopify. Try again.";

// App Bridge adds the session token to fetch() calls, so the Rails endpoint knows which store is asking.
export async function fetchJson(url) {
  // A request that never reaches the server (Wi-Fi off, dev server stopped) gets the same friendly message.
  const response = await fetch(url).catch(() => {
    throw new Error(FALLBACK_ERROR);
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(body.error || FALLBACK_ERROR);
  return body;
}
