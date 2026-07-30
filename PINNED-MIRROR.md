# Pinned 3x-ui qs11 mirror

This repository is a self-contained mirror of `v3.1.0-qs11`.

- Panel release: `v3.1.0-qs11`
- Release assets: hosted by `ShiGuangDe/3x-ui-qs11`
- Installer/menu resources: hosted by `ShiGuangDe/3x-ui-qs11` at tag `v3.1.0-qs11`
- Guided installer SSL choices: Let's Encrypt domain or public-IP certificate
- Web-panel qs update checks and updates: disabled
- Sidebar version link: `ShiGuangDe/3x-ui-qs11`
- Server command `x-ui update`: opt-in migration to the latest official
  `MHSanaei/3x-ui` release after an explicit warning

Install:

```bash
TAG='v3.1.0-qs11'
XUI_AUTO=1 bash <(curl -Ls "https://raw.githubusercontent.com/ShiGuangDe/3x-ui-qs11/${TAG}/install.sh") "${TAG}"
```

The installer always deploys the mirrored qs11 release. During SSL setup,
choose a domain certificate or a short-lived public-IP certificate. Public port
80 must reach the VPS for either ACME challenge.

Verify downloaded release assets with the `SHA256SUMS` file attached to
the GitHub Release.

The original project remains credited through its existing license and
source history metadata. This mirror exists for availability and
reproducible deployment of the pinned release.
