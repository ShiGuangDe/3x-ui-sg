# Frozen 3x-ui mirror

This repository is a self-contained mirror of `v3.1.0-qs11`.

- Panel release: `v3.1.0-qs11`
- Release assets: hosted by `ShiGuangDe/3x-ui-qs11`
- Installer/menu resources: hosted by `ShiGuangDe/3x-ui-qs11` at tag `v3.1.0-qs11`
- Automatic and manual panel upgrades: disabled
- Other panel versions: intentionally unavailable

Install:

```bash
TAG='v3.1.0-qs11'
bash <(curl -Ls "https://raw.githubusercontent.com/ShiGuangDe/3x-ui-qs11/${TAG}/install.sh") "${TAG}"
```

Verify downloaded release assets with the `SHA256SUMS` file attached to
the GitHub Release.

The original project remains credited through its existing license and
source history metadata. This mirror exists for availability and
reproducible deployment of the pinned release.
