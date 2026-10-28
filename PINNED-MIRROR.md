# Versioned 3x-ui SG mirror

This repository is a self-contained mirror with versioned SG releases.

- Original stable release: `v3.1.0-sg1`
- Previous dashboard release: `v3.1.0-sg2`
- Previous release: `v3.1.0-sg3` (in-place updates and fixes)
- Current release: `v3.1.0-sg4` (independent HTTP/3 UDP subscriptions)
- Release assets: hosted by `ShiGuangDe/3x-ui-sg`
- Installer/menu resources: main-branch scripts hosted by `ShiGuangDe/3x-ui-sg`
- Guided installer SSL choices: Let's Encrypt domain or public-IP certificate
- Interactive installer version selection, with `XUI_VERSION` and the first
  command argument available for unattended installs
- Web-panel third-party update checks and updates: disabled
- Sidebar version link: `ShiGuangDe/3x-ui-sg`
- Server command `x-ui update`: choose a verified SG in-place update (default)
  or opt-in migration to the latest official `MHSanaei/3x-ui` release

Install:

```bash
bash <(curl -Ls "https://raw.githubusercontent.com/ShiGuangDe/3x-ui-sg/main/install.sh")
```

New installs default to `v3.1.0-sg4`; `sg1`, `sg2` and `sg3` remain selectable.
HTTP/3 subscriptions are opt-in and require a compatible client. See [setup and limitations](./HTTP3-SUBSCRIPTION.md).
Existing installations are routed to the SG updater without reinstalling. For unattended deployment,
set `XUI_VERSION` or pass the version as the first argument. During SSL setup,
choose a domain certificate or a short-lived public-IP certificate. Public
port 80 must reach the VPS for either ACME challenge.

Verify downloaded release assets with the `SHA256SUMS` file attached to
the GitHub Release.

The original project remains credited through its existing license and
source history metadata. This mirror exists for availability and
reproducible deployment of the pinned release.

SG update packages remain versioned Release assets verified with SHA256SUMS.
The management menu and update launcher track this repository's main branch,
including when updating from an older sg1/sg2 package. Existing release tags
are not moved. SG updates back up the panel files and configured database,
briefly stop the service, and attempt rollback on replacement/startup failure.
