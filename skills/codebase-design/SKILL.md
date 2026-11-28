---
name: codebase-design
description: Vocabulary for a deep module. Use when choosing a boundary, when review-code-quality leaves a shape question, or when the user says deep module, seam, or interface.
argument-hint: "[module or path]"
---

# Module shape

The clean-code script measures size, nesting, and names. This skill is the judgment that script cannot make.

| Term | Means |
| --- | --- |
| Module | A unit with one job and one interface |
| Interface | What callers must know. Small |
| Depth | Behavior behind that interface. Deep means a lot of behavior behind a small interface |
| Seam | The boundary a test can call without reaching inside |
| Adapter | The edge that talks to a system the module does not own |
| Locality | A change for one reason lands in one module |

## When choosing

1. Name the caller and the one job
2. Write the interface in a few lines. A caller that must know the steps inside is a leak
3. Put the seam on that interface
4. A second caller of the same part → lift, per [business-capability-structure](../../rules/business-capability-structure.md)

Do not split a module because a file is long. Split when two jobs share an interface, or one interface covers two jobs.
