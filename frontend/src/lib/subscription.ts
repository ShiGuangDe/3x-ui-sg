export interface Http3SubscriptionSettings {
  subH3Enable?: boolean;
  subH3URI?: string;
}

// A QR code contains an HTTPS URL, not a protocol selector. Only a client
// with a direct HTTP/3 downloader can use it without a TCP connection.
export function http3SubscriptionLink(settings?: Http3SubscriptionSettings, subId?: string): string {
  if (!settings?.subH3Enable || !settings.subH3URI || !subId) return '';
  try {
    const url = new URL(settings.subH3URI);
    if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash || !url.pathname.endsWith('/')) return '';
    return settings.subH3URI + encodeURIComponent(subId);
  } catch {
    return '';
  }
}
