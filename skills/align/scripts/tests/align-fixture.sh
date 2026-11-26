#!/usr/bin/env bash
NAME=template-gallery
ADR=adr/2025-01-02-use-grid.md

write_good() {
  local d="$1"
  mkdir -p "$d/adr"
  cat > "$d/spec.md" <<'DOC'
# Spec: Template gallery

## Goal

Let a [[member]] browse and preview templates before choosing one.

## Users

- A member picking a starting template

## Scope

- Gallery grid, preview, search

## Non-goals

- Authoring templates

## Acceptance criteria

- AC-1: the gallery lists every published template
- AC-2: a preview opens without leaving the gallery

## Constraints

- Works at 320 px width

## Design sources

| Source | Authority | Agreed deviations | Open questions |
| --- | --- | --- | --- |
| [frame](https://example.com/frame) | partial | none | empty state |

## Decisions

- [Use a grid](adr/2025-01-02-use-grid.md)

## Open questions

- (non-blocking) Should search be fuzzy?
DOC
  cat > "$d/glossary.md" <<'DOC'
# Glossary: Template gallery

## Terms

| Term | Definition | Avoid | Source |
| --- | --- | --- | --- |
| Member | A signed-in person | user | human |

## Differs from code

| Term | Human means | Code or docs say |
| --- | --- | --- |
| Template | a starter layout | a row in templates |
DOC
  cat > "$d/alignment.md" <<'DOC'
# Alignment: Template gallery

## Task

Build a browsable template gallery with preview.

## Agreed

- Grid layout

## Assumptions

- Published means visible to all members

## Open questions

- (non-blocking) Should search be fuzzy?

## Status

Aligned: yes
Confirmed by: product owner
DOC
  cat > "$d/$ADR" <<'DOC'
# Use grid

Date: 2025-01-02
Status: accepted
Supersedes: none

## Context

A list hides thumbnails.

## Decision

Use a grid.

## Alternatives

- List: hides thumbnails

## Consequences

- Needs responsive columns
DOC
}
