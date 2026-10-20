# Changelog

## 1.0.0 — 2026-10-20

Initial public release.

- 11 DSH tools: hot, search, video, user, status, login start/status/submit, manual verify, guarded comment, publish interface.
- Read path: dy-cli reverse API, with an Edge page-XHR fallback for endpoints that reject the reverse client.
- `search_id` chaining for search pagination (offset alone returns an empty page).
- Pollable QR/SMS login state machine with a dedicated Edge profile.
- Account fingerprint from the creator's own work list (title + publish time + work id, SHA-256).
- Single worker, 3–8 s page jitter, hourly budget, exponential backoff, `verify_check` detection.
- Credential redaction in tool results and logs; writes disabled by default.