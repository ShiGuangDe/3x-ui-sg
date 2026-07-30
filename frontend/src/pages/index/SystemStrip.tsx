import { useTranslation } from 'react-i18next';
import { Card, Tooltip } from 'antd';
import {
  ClockCircleOutlined,
  DatabaseOutlined,
  EyeInvisibleOutlined,
  EyeOutlined,
  GlobalOutlined,
} from '@ant-design/icons';

import { SizeFormatter } from '@/utils';
import type { Status } from '@/models/status';

interface SystemStripProps {
  status: Status;
  showIp: boolean;
  onToggleIp: () => void;
}

export default function SystemStrip({ status, showIp, onToggleIp }: SystemStripProps) {
  const { t } = useTranslation();
  const formatDuration = (seconds: number) => {
    if (seconds < 60) return t('pages.index.durationSeconds', { value: Math.floor(seconds) });
    if (seconds < 3600) return t('pages.index.durationMinutes', { value: Math.floor(seconds / 60) });
    if (seconds < 86400) return t('pages.index.durationHours', { value: Math.floor(seconds / 3600) });
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds - days * 86400) / 3600);
    return hours > 0
      ? t('pages.index.durationDaysHours', { days, hours })
      : t('pages.index.durationDays', { value: days });
  };

  return (
    <Card hoverable styles={{ body: { padding: 0 } }}>
      <div className="ov-strip-grid">
        <div className="ov-strip-cell">
          <div className="ov-kicker ov-kicker-icon">
            <ClockCircleOutlined />
            {t('pages.index.uptime')}
          </div>
          <div className="ov-strip-split">
            <div>
              <div className="ov-strip-sub">{t('pages.index.xrayStatus')}</div>
              <div className="ov-strip-value">{formatDuration(status.appStats.uptime)}</div>
            </div>
            <span className="ov-strip-split-sep" />
            <div>
              <div className="ov-strip-sub">{t('pages.index.operatingSystem')}</div>
              <div className="ov-strip-value">{formatDuration(status.uptime)}</div>
            </div>
          </div>
        </div>

        <div className="ov-strip-cell">
          <div className="ov-kicker ov-kicker-icon">
            <DatabaseOutlined />
            {t('pages.index.panel')}
          </div>
          <div className="ov-strip-split">
            <div>
              <div className="ov-strip-sub">{t('pages.index.memory')}</div>
              <div className="ov-strip-value">{SizeFormatter.sizeFormat(status.appStats.mem)}</div>
            </div>
            <span className="ov-strip-split-sep" />
            <div>
              <div className="ov-strip-sub">{t('pages.index.threads')}</div>
              <div className="ov-strip-value">{status.appStats.threads}</div>
            </div>
          </div>
        </div>

        <div className="ov-strip-cell">
          <div className="ov-kicker ov-kicker-icon">
            <GlobalOutlined />
            {t('pages.index.ipAddresses')}
            <Tooltip title={t('pages.index.toggleIpVisibility')}>
              <button
                type="button"
                className="ov-ip-toggle"
                aria-label={t('pages.index.toggleIpVisibility')}
                onClick={onToggleIp}
              >
                {showIp ? <EyeOutlined /> : <EyeInvisibleOutlined />}
              </button>
            </Tooltip>
          </div>
          <div className={`ov-ip${showIp ? '' : ' ip-hidden'}`}>
            <div className="ov-mono">{status.publicIP.ipv4}</div>
            <div className="ov-mono ov-ip-v6">{status.publicIP.ipv6}</div>
          </div>
        </div>
      </div>
    </Card>
  );
}
