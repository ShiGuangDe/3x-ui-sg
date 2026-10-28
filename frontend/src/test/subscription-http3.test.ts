import { describe, expect, it } from 'vitest';
import { http3SubscriptionLink } from '@/lib/subscription';
import { AllSetting } from '@/models/setting';
import { DefaultsPayloadSchema } from '@/schemas/defaults';

describe('HTTP/3 subscription QR links', () => {
  it('stays off on existing installations', () => {
    expect(new AllSetting({ subEnable: true }).subH3Enable).toBe(false);
    expect(http3SubscriptionLink(undefined, 'client')).toBe('');
    expect(http3SubscriptionLink({ subH3Enable: false, subH3URI: 'https://sub.example/sub/' }, 'client')).toBe('');
  });
  it('works independently of the TCP service and preserves the ID', () => {
    const settings = new AllSetting({ subEnable: false, subH3Enable: true, subH3URI: 'https://sub.example:2097/sub/' });
    expect(http3SubscriptionLink(settings, 'my/id')).toBe('https://sub.example:2097/sub/my%2Fid');
    expect(DefaultsPayloadSchema.parse(settings).subH3Enable).toBe(true);
  });
  it.each(['http://sub.example/sub/', 'udp://sub.example/sub/', 'https://user:pass@sub.example/sub/', 'https://sub.example/sub/?token=x', 'https://sub.example/sub/#x', 'https://sub.example/sub', 'invalid'])('rejects invalid base URL %s', (subH3URI) => {
    expect(http3SubscriptionLink({ subH3Enable: true, subH3URI }, 'client')).toBe('');
  });
  it('does not generate a link without an ID', () => {
    expect(http3SubscriptionLink({ subH3Enable: true, subH3URI: 'https://sub.example/sub/' })).toBe('');
  });
});
