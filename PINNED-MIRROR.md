# Versioned 3x-ui SG mirror

This repository is a self-contained mirror with two selectable SG releases.

- Original stable release: `v3.1.0-sg1`
- Updated dashboard release: `v3.1.0-sg2`
- Release assets: hosted by `ShiGuangDe/3x-ui-sg`
- Installer/menu resources: hosted by `ShiGuangDe/3x-ui-sg`
- Guided installer SSL choices: Let's Encrypt domain or public-IP certificate
- Interactive installer version selection, with `XUI_VERSION` and the first
  command argument available for unattended installs
- Web-panel third-party update checks and updates: disabled
- Sidebar version link: `ShiGuangDe/3x-ui-sg`
- Server command `x-ui update`: opt-in migration to the latest official
  `MHSanaei/3x-ui` release after an explicit warning

Install:

```bash
bash <(curl -Ls "https://raw.githubusercontent.com/ShiGuangDe/3x-ui-sg/v3.1.0-sg2/install.sh")
```

Choose `v3.1.0-sg1` or `v3.1.0-sg2` interactively. For unattended deployment,
set `XUI_VERSION` or pass the version as the first argument. During SSL setup,
choose a domain certificate or a short-lived public-IP certificate. Public
port 80 must reach the VPS for either ACME challenge.

Verify downloaded release assets with the `SHA256SUMS` file attached to
the GitHub Release.

The original project remains credited through its existing license and
source history metadata. This mirror exists for availability and
reproducible deployment of the pinned release.
