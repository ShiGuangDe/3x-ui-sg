import { useEffect, useMemo, useState } from 'react';

import { HttpUtil } from '@/utils';
import type { Status } from '@/models/status';

const OVERVIEW_WINDOW = 72;
const SEED_BUCKET_SECONDS = 2;
const SERIES_KEYS = [
  'cpu',
  'mem',
  'swap',
  'diskUsage',
  'netUp',
  'netDown',
  'tcpCount',
  'udpCount',
] as const;

export type OverviewSeriesKey = (typeof SERIES_KEYS)[number];

export interface OverviewHistory {
  series: Record<OverviewSeriesKey, number[]>;
  labels: string[];
}

interface HistoryPoint {
  t: number;
  v: number;
}

interface HistoryWindow {
  series: Record<OverviewSeriesKey, number[]>;
  times: number[];
}

function emptySeries(): Record<OverviewSeriesKey, number[]> {
  return Object.fromEntries(
    SERIES_KEYS.map((key) => [key, [] as number[]]),
  ) as Record<OverviewSeriesKey, number[]>;
}

function emptyWindow(): HistoryWindow {
  return { series: emptySeries(), times: [] };
}

function sampleOf(status: Status): Record<OverviewSeriesKey, number> {
  return {
    cpu: status.cpu.percent,
    mem: status.mem.percent,
    swap: status.swap.percent,
    diskUsage: status.disk.percent,
    netUp: status.netIO.up,
    netDown: status.netIO.down,
    tcpCount: status.tcpCount,
    udpCount: status.udpCount,
  };
}

function tailWindow<T>(values: T[]): T[] {
  return values.slice(-OVERVIEW_WINDOW);
}

function formatClock(unixSeconds: number): string {
  const date = new Date(unixSeconds * 1000);
  const hh = String(date.getHours()).padStart(2, '0');
  const mm = String(date.getMinutes()).padStart(2, '0');
  const ss = String(date.getSeconds()).padStart(2, '0');
  return `${hh}:${mm}:${ss}`;
}

export function mean(values: number[]): number {
  if (values.length === 0) return 0;
  return values.reduce((total, value) => total + value, 0) / values.length;
}

export function peak(values: number[]): number {
  return values.reduce((max, value) => Math.max(max, value), 0);
}

export function useOverviewHistory(status: Status, hasData: boolean): OverviewHistory {
  const [trend, setTrend] = useState<HistoryWindow>(emptyWindow);

  useEffect(() => {
    let cancelled = false;

    async function seed() {
      const responses = new Map<OverviewSeriesKey, HistoryPoint[]>();
      await Promise.all(
        SERIES_KEYS.map(async (key) => {
          const msg = await HttpUtil.get<HistoryPoint[]>(
            `/panel/api/server/history/${key}/${SEED_BUCKET_SECONDS}`,
            undefined,
            { silent: true },
          );
          if (msg?.success && Array.isArray(msg.obj)) responses.set(key, msg.obj);
        }),
      );
      if (cancelled || responses.size === 0) return;

      let axis: HistoryPoint[] = [];
      for (const points of responses.values()) {
        if (points.length > axis.length) axis = points;
      }
      axis = tailWindow(axis);
      if (axis.length === 0) return;

      const seedTimes = axis.map((point) => Number(point.t) || 0);
      const seedSeries = emptySeries();
      for (const key of SERIES_KEYS) {
        const byTimestamp = new Map<number, number>();
        for (const point of responses.get(key) ?? []) {
          byTimestamp.set(Number(point.t) || 0, Number(point.v) || 0);
        }
        seedSeries[key] = seedTimes.map((timestamp) => byTimestamp.get(timestamp) ?? 0);
      }

      setTrend((previous) => {
        const merged = emptyWindow();
        merged.times = tailWindow(seedTimes.concat(previous.times));
        for (const key of SERIES_KEYS) {
          merged.series[key] = tailWindow(seedSeries[key].concat(previous.series[key]));
        }
        return merged;
      });
    }

    seed().catch(() => undefined);
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (!hasData) return;
    setTrend((previous) => {
      const point = sampleOf(status);
      const next = emptyWindow();
      next.times = tailWindow(previous.times.concat(Math.floor(Date.now() / 1000)));
      for (const key of SERIES_KEYS) {
        next.series[key] = tailWindow(previous.series[key].concat(point[key]));
      }
      return next;
    });
  }, [status, hasData]);

  const labels = useMemo(() => trend.times.map(formatClock), [trend.times]);
  return useMemo(() => ({ series: trend.series, labels }), [trend.series, labels]);
}
