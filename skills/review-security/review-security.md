---
name: review-security
description: Review a diff for security: authn/authz, input handling, injection, secrets, crypto, unsafe deserialization, TLS. Use when review's stages.sh turns it on (auth/secret paths or risky tokens), or alone for "security review".
argument-hint: "[PR/MR number | branch] [plan path]"
---

# review-security

One stage of [review](../review/review.md). Findings: format per [review](../review/review.md) (severity bug · suggestion · nit, stage id, `file:line`, description, fix). Read-only. Never edit code.

## Check

- Every route, handler, or job checks authentication and authorization for the acting user and the object
- Input validated and encoded for its sink: SQL, shell, HTML, paths, URLs, templates
- No secrets, tokens, or personal data in code, logs, errors, or test fixtures
- Crypto: vetted libraries, current algorithms. Security randomness not `Math.random`. TLS verification on
- Deserialization, `eval`, `exec`, process spawning take no untrusted input

## Not here

Dependency choice → review-dependencies. Runtime config → review-infra.
