import { Collapse, Divider, Input, InputNumber, Switch } from 'antd';
import { useTranslation } from 'react-i18next';
import type { AllSetting } from '@/models/setting';
import SettingListItem from '@/components/SettingListItem';

interface SubscriptionGeneralTabProps {
  allSetting: AllSetting;
  updateSetting: (patch: Partial<AllSetting>) => void;
}

function sanitizePath(input: string): string {
  return String(input ?? '').replace(/[:*]/g, '');
}

function normalizePath(input: string): string {
  let p = input || '/';
  if (!p.startsWith('/')) p = '/' + p;
  if (!p.endsWith('/')) p += '/';
  p = p.replace(/\/+/g, '/');
  return p;
}

export default function SubscriptionGeneralTab({ allSetting, updateSetting }: SubscriptionGeneralTabProps) {
  const { t } = useTranslation();

  return (
    <Collapse defaultActiveKey="1" items={[
      {
        key: '1',
        label: `${t('pages.settings.panelSettings')} — HTTP(S) / TCP`,
        children: (
          <>
            <SettingListItem paddings="small" title={t('pages.settings.subEnable')} description={t('pages.settings.subEnableDesc')}>
              <Switch checked={allSetting.subEnable} onChange={(v) => updateSetting({ subEnable: v })} />
            </SettingListItem>
            <SettingListItem paddings="small" title="JSON subscription" description={t('pages.settings.subJsonEnable')}>
              <Switch checked={allSetting.subJsonEnable} onChange={(v) => updateSetting({ subJsonEnable: v })} />
            </SettingListItem>
            <SettingListItem paddings="small" title="Clash / Mihomo subscription">
              <Switch checked={allSetting.subClashEnable} onChange={(v) => updateSetting({ subClashEnable: v })} />
            </SettingListItem>
            <SettingListItem paddings="small" title={t('pages.settings.subListen')} description={t('pages.settings.subListenDesc')}>
              <Input value={allSetting.subListen} onChange={(e) => updateSetting({ subListen: e.target.value })} />
            </SettingListItem>
            <SettingListItem paddings="small" title={t('pages.settings.subDomain')} description={t('pages.settings.subDomainDesc')}>
              <Input value={allSetting.subDomain} onChange={(e) => updateSetting({ subDomain: e.target.value })} />
            </SettingListItem>
            <SettingListItem paddings="small" title={t('pages.settings.subPort')} description={t('pages.settings.subPortDesc')}>
              <InputNumber value={allSetting.subPort} min={1} max={65535} style={{ width: '100%' }}
                onChange={(v) => updateSetting({ subPort: Number(v) || 0 })} />
            </SettingListItem>
            <SettingListItem paddings="small" title={t('pages.settings.subPath')} description={t('pages.settings.subPathDesc')}>
              <Input
                value={allSetting.subPath}
                placeholder="/sub/"
                onChange={(e) => updateSetting({ subPath: sanitizePath(e.target.value) })}
                onBlur={() => updateSetting({ subPath: normalizePath(allSetting.subPath) })}
              />
            </SettingListItem>
            <SettingListItem paddings="small" title={t('pages.settings.subURI')} description={t('pages.settings.subURIDesc')}>
              <Input value={allSetting.subURI} placeholder="(http|https)://domain[:port]/path/"
                onChange={(e) => updateSetting({ subURI: e.target.value })} />
            </SettingListItem>
          </>
        ),
      },
      {
        key: 'http3',
        label: t('subscription.http3.title'),
        children: (
          <>
            <p style={{ opacity: 0.75 }}>{t('subscription.http3.compatibility')}</p>
            <SettingListItem paddings="small" title={t('pages.settings.subEnable')} description={t('subscription.http3.enableDesc')}>
              <Switch aria-label={t('subscription.http3.title')} checked={allSetting.subH3Enable} onChange={(v) => updateSetting({ subH3Enable: v })} />
            </SettingListItem>
            <SettingListItem paddings="small" title={t('pages.settings.subListen')} description={t('pages.settings.subListenDesc')}>
              <Input aria-label="HTTP/3 listen" value={allSetting.subH3Listen} onChange={(e) => updateSetting({ subH3Listen: e.target.value.trim() })} />
            </SettingListItem>
            <SettingListItem paddings="small" title={t('subscription.http3.port')} description={t('subscription.http3.portDesc')}>
              <InputNumber aria-label="HTTP/3 UDP port" value={allSetting.subH3Port} min={1} max={65535} style={{ width: '100%' }}
                onChange={(v) => updateSetting({ subH3Port: Number(v) || 0 })} />
            </SettingListItem>
            <SettingListItem paddings="small" title={t('pages.settings.subDomain')} description={t('subscription.http3.domainDesc')}>
              <Input aria-label="HTTP/3 domain" value={allSetting.subH3Domain} placeholder="sub.example.com"
                onChange={(e) => updateSetting({ subH3Domain: e.target.value.trim() })} />
            </SettingListItem>
            <SettingListItem paddings="small" title={t('pages.settings.subCertPath')} description={t('subscription.http3.certDesc')}>
              <Input aria-label="HTTP/3 certificate" value={allSetting.subH3CertFile} onChange={(e) => updateSetting({ subH3CertFile: e.target.value })} />
            </SettingListItem>
            <SettingListItem paddings="small" title={t('pages.settings.subKeyPath')} description={t('subscription.http3.certDesc')}>
              <Input aria-label="HTTP/3 private key" value={allSetting.subH3KeyFile} onChange={(e) => updateSetting({ subH3KeyFile: e.target.value })} />
            </SettingListItem>
            <SettingListItem paddings="small" title={t('pages.settings.subURI')} description={t('subscription.http3.uriDesc')}>
              <Input aria-label="HTTP/3 public URL" value={allSetting.subH3URI} placeholder="https://sub.example.com:2097/sub/"
                onChange={(e) => updateSetting({ subH3URI: e.target.value.trim() })} />
            </SettingListItem>
            <p style={{ opacity: 0.75 }}>{t('subscription.http3.sharedDesc')}</p>
          </>
        ),
      },
      {
        key: '2',
        label: t('pages.settings.information'),
        children: (
          <>
            <SettingListItem paddings="small" title={t('pages.settings.subEncrypt')} description={t('pages.settings.subEncryptDesc')}>
              <Switch checked={allSetting.subEncrypt} onChange={(v) => updateSetting({ subEncrypt: v })} />
            </SettingListItem>
            <SettingListItem paddings="small" title={t('pages.settings.subShowInfo')} description={t('pages.settings.subShowInfoDesc')}>
              <Switch checked={allSetting.subShowInfo} onChange={(v) => updateSetting({ subShowInfo: v })} />
            </SettingListItem>
            <SettingListItem paddings="small" title={t('pages.settings.subEmailInRemark')} description={t('pages.settings.subEmailInRemarkDesc')}>
              <Switch checked={allSetting.subEmailInRemark} onChange={(v) => updateSetting({ subEmailInRemark: v })} />
            </SettingListItem>

            <Divider>{t('pages.settings.subTitle')}</Divider>

            <SettingListItem paddings="small" title={t('pages.settings.subTitle')} description={t('pages.settings.subTitleDesc')}>
              <Input value={allSetting.subTitle} onChange={(e) => updateSetting({ subTitle: e.target.value })} />
            </SettingListItem>
            <SettingListItem paddings="small" title={t('pages.settings.subSupportUrl')} description={t('pages.settings.subSupportUrlDesc')}>
              <Input value={allSetting.subSupportUrl} placeholder="https://example.com"
                onChange={(e) => updateSetting({ subSupportUrl: e.target.value })} />
            </SettingListItem>
            <SettingListItem paddings="small" title={t('pages.settings.subProfileUrl')} description={t('pages.settings.subProfileUrlDesc')}>
              <Input value={allSetting.subProfileUrl} placeholder="https://example.com"
                onChange={(e) => updateSetting({ subProfileUrl: e.target.value })} />
            </SettingListItem>
            <SettingListItem paddings="small" title={t('pages.settings.subAnnounce')} description={t('pages.settings.subAnnounceDesc')}>
              <Input.TextArea value={allSetting.subAnnounce}
                onChange={(e) => updateSetting({ subAnnounce: e.target.value })} />
            </SettingListItem>

            <Divider>Happ</Divider>

            <SettingListItem paddings="small" title={t('pages.settings.subEnableRouting')} description={t('pages.settings.subEnableRoutingDesc')}>
              <Switch checked={allSetting.subEnableRouting} onChange={(v) => updateSetting({ subEnableRouting: v })} />
            </SettingListItem>
            <SettingListItem paddings="small" title={t('pages.settings.subRoutingRules')} description={t('pages.settings.subRoutingRulesDesc')}>
              <Input.TextArea value={allSetting.subRoutingRules} placeholder="happ://routing/add/..."
                onChange={(e) => updateSetting({ subRoutingRules: e.target.value })} />
            </SettingListItem>
          </>
        ),
      },
      {
        key: '3',
        label: t('pages.settings.certs'),
        children: (
          <>
            <SettingListItem paddings="small" title={t('pages.settings.subCertPath')} description={t('pages.settings.subCertPathDesc')}>
              <Input value={allSetting.subCertFile} onChange={(e) => updateSetting({ subCertFile: e.target.value })} />
            </SettingListItem>
            <SettingListItem paddings="small" title={t('pages.settings.subKeyPath')} description={t('pages.settings.subKeyPathDesc')}>
              <Input value={allSetting.subKeyFile} onChange={(e) => updateSetting({ subKeyFile: e.target.value })} />
            </SettingListItem>
          </>
        ),
      },
      {
        key: '4',
        label: t('pages.settings.intervals'),
        children: (
          <>
            <SettingListItem paddings="small" title={t('pages.settings.subUpdates')} description={t('pages.settings.subUpdatesDesc')}>
              <InputNumber value={allSetting.subUpdates} min={1} style={{ width: '100%' }}
                onChange={(v) => updateSetting({ subUpdates: Number(v) || 0 })} />
            </SettingListItem>
          </>
        ),
      },
    ]} />
  );
}
