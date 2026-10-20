# Security

## Credential boundary

- The plugin never returns cookies, `sessionid`, `passport_*`, `localStorage`, or `storage_state` in tool results, logs, or error messages.
- `<dataDir>/home/.dy/cookies/default.json` and `<dataDir>/browser-profile/` contain live credentials. They are git-ignored and must not be committed or shared.
- Logs are redacted before they are written; request/response bodies are not logged.

## Write operations

- `writesEnabled` defaults to `false`.
- A comment is sent only with `writesEnabled: true`, `dry_run: false`, and `confirm: true`.
- The plugin refuses writes when the account fingerprint no longer matches the first recorded account (`account_mismatch`).
- `douyin_publish` is an interface only and never performs an action.

## Captcha and rate limits

- The plugin does not solve, bypass, or outsource captchas. `challenge_required` / `verify_check` stops the call and points to `douyin_verify`, where a human completes the challenge in a visible Edge window.
- Requests are serialized and paced; an hourly budget and exponential backoff reduce the chance of account restrictions.

## Reporting

Please open a GitHub issue for security problems. Do not paste cookies, tokens, or account identifiers into an issue.