import { Alert, Typography } from 'antd';
import { useTranslation } from 'react-i18next';
import QrPanel from './QrPanel';

export default function Http3QrPanel({ value }: { value: string }) {
  const { t } = useTranslation();
  return (
    <>
      <Alert type="info" showIcon title={t('subscription.http3.title')}
        description={t('subscription.http3.qrDesc')} style={{ marginBottom: 16 }} />
      <Typography.Paragraph style={{ overflowWrap: 'anywhere' }}>{value}</Typography.Paragraph>
      <QrPanel value={value} remark={t('subscription.http3.title')} size={260} />
    </>
  );
}
