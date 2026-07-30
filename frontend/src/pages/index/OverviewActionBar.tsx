import { Fragment } from 'react';
import type { ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { Button, Tooltip } from 'antd';
import {
  AreaChartOutlined,
  BarsOutlined,
  CloudServerOutlined,
  ControlOutlined,
  FileTextOutlined,
  PoweroffOutlined,
  ReloadOutlined,
  RiseOutlined,
} from '@ant-design/icons';

import type { Status } from '@/models/status';

interface OverviewActionBarProps {
  status: Status;
  isMobile: boolean;
  accessLogEnable: boolean;
  panelVersion: string;
  onStopXray: () => void;
  onRestartXray: () => void;
  onOpenLogs: () => void;
  onOpenXrayLogs: () => void;
  onOpenConfig: () => void;
  onOpenBackup: () => void;
  onOpenSystemHistory: () => void;
  onOpenXrayMetrics: () => void;
  onOpenPanelRelease: () => void;
  onOpenVersionSwitch: () => void;
}

interface BarAction {
  key: string;
  icon: ReactNode;
  text: string;
  onClick: () => void;
  primary?: boolean;
}

const XRAY_STATE_KEYS: Record<string, string> = {
  running: 'pages.index.xrayStatusRunning',
  stop: 'pages.index.xrayStatusStop',
  error: 'pages.index.xrayStatusError',
};

export default function OverviewActionBar({
  status,
  isMobile,
  accessLogEnable,
  panelVersion,
  onStopXray,
  onRestartXray,
  onOpenLogs,
  onOpenXrayLogs,
  onOpenConfig,
  onOpenBackup,
  onOpenSystemHistory,
  onOpenXrayMetrics,
  onOpenPanelRelease,
  onOpenVersionSwitch,
}: OverviewActionBarProps) {
  const { t } = useTranslation();
  const stateText = t(XRAY_STATE_KEYS[status.xray.state] ?? 'pages.index.xrayStatusUnknown');
  const hasVersion = !!status.xray.version && status.xray.version !== 'Unknown';
  const size = isMobile ? ('small' as const) : ('middle' as const);

  const actionGroups: BarAction[][] = [
    [
      {
        key: 'restart',
        icon: <ReloadOutlined />,
        text: t('pages.index.restartXray'),
        onClick: onRestartXray,
        primary: true,
      },
      {
        key: 'stop',
        icon: <PoweroffOutlined />,
        text: t('pages.index.stopXray'),
        onClick: onStopXray,
      },
    ],
    [
      {
        key: 'logs',
        icon: <BarsOutlined />,
        text: t('pages.index.logs'),
        onClick: onOpenLogs,
      },
      ...(accessLogEnable
        ? [{
            key: 'accessLogs',
            icon: <FileTextOutlined />,
            text: t('pages.index.accessLogs'),
            onClick: onOpenXrayLogs,
          }]
        : []),
      {
        key: 'config',
        icon: <ControlOutlined />,
        text: t('pages.index.config'),
        onClick: onOpenConfig,
      },
      {
        key: 'backup',
        icon: <CloudServerOutlined />,
        text: t('pages.index.backupTitle'),
        onClick: onOpenBackup,
      },
    ],
    [
      {
        key: 'history',
        icon: <AreaChartOutlined />,
        text: t('pages.index.systemHistoryTitle'),
        onClick: onOpenSystemHistory,
      },
      {
        key: 'metrics',
        icon: <RiseOutlined />,
        text: t('pages.index.xrayMetricsTitle'),
        onClick: onOpenXrayMetrics,
      },
    ],
  ];

  const statePill = (
    <span className="ov-state" data-state={status.xray.state}>
      <span className="ov-state-dot" style={{ color: status.xray.color }} />
      <span>{`${t('pages.index.xrayStatus')} · ${stateText}`}</span>
      {hasVersion && (
        <Tooltip title={t('pages.index.xraySwitch')}>
          <button type="button" className="ov-state-version" onClick={onOpenVersionSwitch}>
            {`v${status.xray.version}`}
          </button>
        </Tooltip>
      )}
    </span>
  );

  return (
    <div className="ov-bar">
      {status.xray.state === 'error' && status.xray.errorMsg ? (
        <Tooltip title={<span className="ov-error-detail">{status.xray.errorMsg}</span>}>
          {statePill}
        </Tooltip>
      ) : statePill}

      <Tooltip title={t('pages.index.pinnedRelease')}>
        <button type="button" className="ov-panel-version ov-mono" onClick={onOpenPanelRelease}>
          {`v${panelVersion}`}
        </button>
      </Tooltip>

      <div className="ov-bar-actions">
        {actionGroups.map((group, groupIndex) => (
          <Fragment key={group[0].key}>
            {groupIndex > 0 && <span className="ov-bar-sep" />}
            {group.map((action) => (
              <Button
                key={action.key}
                type={action.primary ? undefined : 'text'}
                color={action.primary ? 'primary' : undefined}
                variant={action.primary ? 'outlined' : undefined}
                size={size}
                icon={action.icon}
                aria-label={action.text}
                onClick={action.onClick}
              >
                {isMobile ? undefined : action.text}
              </Button>
            ))}
          </Fragment>
        ))}
      </div>
    </div>
  );
}
