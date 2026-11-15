const FALLBACK_ERROR = "Couldn't load data from Shopify. Try again.";

// App Bridge adds the session token to fetch() calls, so the Rails endpoint knows which store is asking.
export async function fetchJson<T>(url: string): Promise<T> {
  // A request that never reaches the server (Wi-Fi off, dev server stopped) gets the same friendly message.
  const response = await fetch(url).catch(() => {
    throw new Error(FALLBACK_ERROR);
  });
  const body: unknown = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error((body as { error?: string }).error || FALLBACK_ERROR);
  }
  // TypeScript can't check data from the network: the caller names the shape it expects (see types.ts).
  return body as T;
}
