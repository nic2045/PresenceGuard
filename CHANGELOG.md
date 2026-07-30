# Changelog

## [0.5.0](https://github.com/nic2045/PresenceGuard/compare/v0.4.0...v0.5.0) (2026-07-30)


### ⚠ BREAKING CHANGES

* remove the schedule blueprint ([#62](https://github.com/nic2045/PresenceGuard/issues/62))

### Features

* remove the schedule blueprint ([#62](https://github.com/nic2045/PresenceGuard/issues/62)) ([ab238f9](https://github.com/nic2045/PresenceGuard/commit/ab238f919866b51ebe7ae1f91ab82deed6b7c3a7))

## [0.4.0](https://github.com/nic2045/PresenceGuard/compare/v0.3.15...v0.4.0) (2026-07-30)


### ⚠ BREAKING CHANGES

* remove the classic bash/YAML setup ([#61](https://github.com/nic2045/PresenceGuard/issues/61))

### Features

* remove the classic bash/YAML setup ([#61](https://github.com/nic2045/PresenceGuard/issues/61)) ([3299f9e](https://github.com/nic2045/PresenceGuard/commit/3299f9e65b8e59e27c44cf800fb578b568338306))


### Bug Fixes

* force token refresh and retry once on Graph 401 ([#58](https://github.com/nic2045/PresenceGuard/issues/58)) ([982d974](https://github.com/nic2045/PresenceGuard/commit/982d97490b975ec98a43c111183b977896d8f041))
* harden Graph client and enforce ruff lint in CI ([#60](https://github.com/nic2045/PresenceGuard/issues/60)) ([08be2fc](https://github.com/nic2045/PresenceGuard/commit/08be2fc7aa234beb72847e2c491f0416da1b9c75))

## [0.3.15](https://github.com/nic2045/PresenceGuard/compare/v0.3.14...v0.3.15) (2026-07-28)


### Bug Fixes

* retry token refresh on transient errors to avoid hourly outages ([#56](https://github.com/nic2045/PresenceGuard/issues/56)) ([6d9b899](https://github.com/nic2045/PresenceGuard/commit/6d9b89963e9c6dfd98f756a280392950b2bb9187))

## [0.3.14](https://github.com/nic2045/PresenceGuard/compare/v0.3.13...v0.3.14) (2026-06-02)


### Features

* add presence select entity to change Teams status from device ([#52](https://github.com/nic2045/PresenceGuard/issues/52)) ([2a8d472](https://github.com/nic2045/PresenceGuard/commit/2a8d4721c3872f6874f0d21647268a84234749e8))
* clear_presence fallback + verify set actions + robust Graph calls ([#54](https://github.com/nic2045/PresenceGuard/issues/54)) ([cbdb4cd](https://github.com/nic2045/PresenceGuard/commit/cbdb4cd2edbba44971f42ae2ea6241fae7d71fab))

## [0.3.13](https://github.com/nic2045/PresenceGuard/compare/v0.3.12...v0.3.13) (2026-06-01)


### Bug Fixes

* load failure from wrong DeviceInfo import and presence sensor masking poll/auth failures ([#47](https://github.com/nic2045/PresenceGuard/issues/47)) ([e4627a9](https://github.com/nic2045/PresenceGuard/commit/e4627a9e35090b37ab12a10890336bab87970268))

## [0.3.12](https://github.com/nic2045/PresenceGuard/compare/v0.3.11...v0.3.12) (2026-06-01)


### Bug Fixes

* set device manufacturer and model in HA device info ([#45](https://github.com/nic2045/PresenceGuard/issues/45)) ([d84798b](https://github.com/nic2045/PresenceGuard/commit/d84798b285966db398b3da4e8d3014b19236c5e9))

## [0.3.11](https://github.com/nic2045/PresenceGuard/compare/v0.3.10...v0.3.11) (2026-05-29)


### Features

* restore presence state across HA restarts ([#43](https://github.com/nic2045/PresenceGuard/issues/43)) ([cb2753e](https://github.com/nic2045/PresenceGuard/commit/cb2753e401363be65b21fb8b841352db4b5ae92c))

## [0.3.10](https://github.com/nic2045/PresenceGuard/compare/v0.3.9...v0.3.10) (2026-05-29)


### Bug Fixes

* presence sensor keeps last valid status across hiccups ([#41](https://github.com/nic2045/PresenceGuard/issues/41)) ([d971401](https://github.com/nic2045/PresenceGuard/commit/d9714010064c5eb743d93431bb270443488f1dc0))

## [0.3.9](https://github.com/nic2045/PresenceGuard/compare/v0.3.8...v0.3.9) (2026-05-29)


### Features

* ship brand icon in the integration (HA 2026.3 brand/ folder) ([#38](https://github.com/nic2045/PresenceGuard/issues/38)) ([731933f](https://github.com/nic2045/PresenceGuard/commit/731933f7d1c08d100b78b9fc99ba893c1ac7a1a9))

## [0.3.8](https://github.com/nic2045/PresenceGuard/compare/v0.3.7...v0.3.8) (2026-05-29)


### Bug Fixes

* **brands:** full-bleed trimmed icon ([#36](https://github.com/nic2045/PresenceGuard/issues/36)) ([c18c426](https://github.com/nic2045/PresenceGuard/commit/c18c426cee2a76cfa8f58aacca75c2693128926a))

## [0.3.7](https://github.com/nic2045/PresenceGuard/compare/v0.3.6...v0.3.7) (2026-05-29)


### Features

* configurable presence poll interval (options flow) ([#34](https://github.com/nic2045/PresenceGuard/issues/34)) ([44e66a7](https://github.com/nic2045/PresenceGuard/commit/44e66a70537f9299ea3669ebce3e35a724fd4ec0))

## [0.3.6](https://github.com/nic2045/PresenceGuard/compare/v0.3.5...v0.3.6) (2026-05-29)


### Bug Fixes

* sync integration manifest version with releases ([#32](https://github.com/nic2045/PresenceGuard/issues/32)) ([e14b743](https://github.com/nic2045/PresenceGuard/commit/e14b743408dfadcde5f4efaef2c76068de7b3ef9))

## [0.3.5](https://github.com/nic2045/PresenceGuard/compare/v0.3.4...v0.3.5) (2026-05-28)


### Features

* integration-native presence blueprint (presenceguard.* services) ([#29](https://github.com/nic2045/PresenceGuard/issues/29)) ([df2de57](https://github.com/nic2045/PresenceGuard/commit/df2de5751b1c0e97cd91c7dd821cfe49617206f3))

## [0.3.4](https://github.com/nic2045/PresenceGuard/compare/v0.3.3...v0.3.4) (2026-05-28)


### Features

* presence sensor entity (current Teams status) ([#27](https://github.com/nic2045/PresenceGuard/issues/27)) ([1560450](https://github.com/nic2045/PresenceGuard/commit/1560450e1ecfdd18218b34b824d79594fa631df6))

## [0.3.3](https://github.com/nic2045/PresenceGuard/compare/v0.3.2...v0.3.3) (2026-05-28)


### Features

* brand icon assets + service icons (icons.json) ([#25](https://github.com/nic2045/PresenceGuard/issues/25)) ([7c7f1fe](https://github.com/nic2045/PresenceGuard/commit/7c7f1fe083fa4bb904a22bf51dc7a78d6d36e0ce))

## [0.3.2](https://github.com/nic2045/PresenceGuard/compare/v0.3.1...v0.3.2) (2026-05-28)


### Features

* HA Custom-Integration (OAuth-UI-Login + Reauth in Reparaturen) ([#22](https://github.com/nic2045/PresenceGuard/issues/22)) ([ab72f19](https://github.com/nic2045/PresenceGuard/commit/ab72f19e981cb8ef59efb7c31764524f313b6f20))

## [0.3.1](https://github.com/nic2045/PresenceGuard/compare/v0.3.0...v0.3.1) (2026-05-28)


### Features

* Token-Warnung in den Presence-Blueprint integrieren (UI + Erneuern-Link) ([#19](https://github.com/nic2045/PresenceGuard/issues/19)) ([3620933](https://github.com/nic2045/PresenceGuard/commit/3620933a494fb5c0fe0372e1c03a14d086f1e52b))

## [0.3.0](https://github.com/nic2045/PresenceGuard/compare/v0.2.7...v0.3.0) (2026-05-28)


### ⚠ BREAKING CHANGES

* user_id automatisch via /me + App-only-Weg entfernen ([#15](https://github.com/nic2045/PresenceGuard/issues/15))

### Features

* user_id automatisch via /me + App-only-Weg entfernen ([#15](https://github.com/nic2045/PresenceGuard/issues/15)) ([e736174](https://github.com/nic2045/PresenceGuard/commit/e736174e3dd000462de093c612f16635216da1f0))

## [0.2.7](https://github.com/nic2045/PresenceGuard/compare/v0.2.6...v0.2.7) (2026-05-28)


### Features

* Setup-Wizard merkt Werte + wiederholbares Fehlerhandling ([#13](https://github.com/nic2045/PresenceGuard/issues/13)) ([06861f0](https://github.com/nic2045/PresenceGuard/commit/06861f0f57f9180b0cf3cb6dd67d03ec674a2a0b))

## [0.2.6](https://github.com/nic2045/PresenceGuard/compare/v0.2.5...v0.2.6) (2026-05-28)


### Features

* interaktiver Setup-Wizard (setup_presenceguard.sh) ([#11](https://github.com/nic2045/PresenceGuard/issues/11)) ([88b8e6a](https://github.com/nic2045/PresenceGuard/commit/88b8e6a59f7b771dbcbf02a7c7e1ef2fb2fb43f1))

## [0.2.5](https://github.com/nic2045/PresenceGuard/compare/v0.2.4...v0.2.5) (2026-05-28)


### Features

* Blueprint-Version anzeigen + an release-please koppeln ([#9](https://github.com/nic2045/PresenceGuard/issues/9)) ([6728100](https://github.com/nic2045/PresenceGuard/commit/672810051d1b52f2ce07d7a95b41591fa9ee264e))

## [0.2.4](https://github.com/nic2045/PresenceGuard/compare/v0.2.3...v0.2.4) (2026-05-28)


### Features

* zwei Auth-Wege (delegiert + App-only) mit Auto-Erkennung ([#7](https://github.com/nic2045/PresenceGuard/issues/7)) ([42300a3](https://github.com/nic2045/PresenceGuard/commit/42300a334b47b4f17612eed1394e4c060e9fed24))

## [0.2.3](https://github.com/nic2045/PresenceGuard/compare/v0.2.2...v0.2.3) (2026-05-28)


### Features

* UI-Status-Sensor für Token + robuster Token-Sensor ([#5](https://github.com/nic2045/PresenceGuard/issues/5)) ([c329636](https://github.com/nic2045/PresenceGuard/commit/c3296363e44a2e0ad61874237211a004b24f92c7))

## [0.2.2](https://github.com/nic2045/PresenceGuard/compare/v0.2.1...v0.2.2) (2026-05-28)


### Features

* UI-Blueprint + Repo-Struktur/Validierung aus ha-garden-water ([#3](https://github.com/nic2045/PresenceGuard/issues/3)) ([f361bbd](https://github.com/nic2045/PresenceGuard/commit/f361bbd124f88b79362e05d76c880eceac78d029))

## [0.2.1](https://github.com/nic2045/PresenceGuard/compare/v0.2.0...v0.2.1) (2026-05-28)


### Features

* PresenceGuard – auto-set Teams presence via Home Assistant + Graph ([#1](https://github.com/nic2045/PresenceGuard/issues/1)) ([71237dd](https://github.com/nic2045/PresenceGuard/commit/71237dd209c08e9721853de31bb03ad3032640cf))

## Changelog

Maintained automatically by [release-please](https://github.com/googleapis/release-please).
