---
name: review-security
description: Review a diff for security: authn/authz, input handling, injection, secrets, crypto, unsafe deserialization, TLS. Use when review's stages.sh turns it on (auth/secret paths or risky tokens), or alone for "security review".
argument-hint: "[PR/MR number | branch] [plan path]"
---

# review-security

One stage of [review](../review/review.md). Findings use the format in [review](../review/review.md): severity (bug · suggestion · nit), stage id, `file:line`, description, fix. Read-only: never edit code.

## Check

- Every new route, handler, or job checks authentication and authorization for the acting user and the object
- Input is validated and encoded for its sink: SQL, shell, HTML, paths, URLs, templates
- No secrets, tokens, or personal data in code, logs, errors, or test fixtures
- Crypto uses vetted libraries and current algorithms; randomness for security is not `Math.random`; TLS verification stays on
- Deserialization, `eval`, `exec`, and process spawning take no untrusted input
- New dependencies are covered by review-dependencies; config exposure by review-infra

## Not here

Dependency choice (review-dependencies), runtime config (review-infra).
