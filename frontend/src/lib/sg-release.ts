export const SG_REPO_URL = 'https://github.com/ShiGuangDe/3x-ui-sg';

export function panelReleaseUrl(version: string): string {
  return `${SG_REPO_URL}/releases/tag/${encodeURIComponent(`v${version.trim().replace(/^v/, '')}`)}`;
}
