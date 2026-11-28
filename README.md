# Public AI

You bring an idea. The line carries it to production.

## Start here

> [!TIP]
> Say **`/idea-to-production`** and the idea.
>
> That name spells the whole range: from the idea to production.

`/idea-to-prod` is the short form of the same range.

| You want | Say |
| --- | --- |
| Nothing on the line yet, and you want it working | `/build` |
| A run that ends with something shipped | `/deliver` |
| This run to move one station forward | `/advance` |

> [!NOTE]
> `/apirvw` is the same line for people who already know the letters. It is a shortcut, not the way in.

## The line

Read top to bottom. Each box is one station. A skill runs it. A script passes or fails the check. The agent judges only what a script cannot.

```mermaid
flowchart TB
  idea["Idea · what you want"]:::idea
  align["Align · agree the picture"]:::align
  plan["Plan · write it down"]:::plan
  build["Implement · make it work"]:::build
  review["Review · check it against the plan"]:::review
  prove["Verify · prove it on the pull request"]:::prove
  watch["Watch · pipeline goes green"]:::watch
  merge["You merge"]:::you
  prod["Production"]:::prod
  monitor["Monitor · watch the deploy"]:::mon
  idea --> align --> plan --> build --> review --> prove --> watch --> merge --> prod --> monitor
  classDef idea fill:#FDE68A,stroke:#B45309,color:#1C1917,stroke-width:2px
  classDef align fill:#FDBA74,stroke:#C2410C,color:#1C1917,stroke-width:2px
  classDef plan fill:#99F6E4,stroke:#0F766E,color:#042F2E,stroke-width:2px
  classDef build fill:#86EFAC,stroke:#15803D,color:#052E16,stroke-width:2px
  classDef review fill:#93C5FD,stroke:#1D4ED8,color:#172554,stroke-width:2px
  classDef prove fill:#C4B5FD,stroke:#6D28D9,color:#2E1065,stroke-width:2px
  classDef watch fill:#F9A8D4,stroke:#BE185D,color:#500724,stroke-width:2px
  classDef you fill:#FECACA,stroke:#B91C1C,color:#450A0A,stroke-width:2px
  classDef prod fill:#6EE7B7,stroke:#047857,color:#022C22,stroke-width:2px
  classDef mon fill:#A5F3FC,stroke:#0E7490,color:#083344,stroke-width:2px
```

| Station | What you get |
| --- | --- |
| Align | A shared picture: goal, terms, decisions, and what a person can see |
| Plan | That picture, written once |
| Implement | Code, unit tests, and a few tests from outside the app |
| Review | A read of the diff against the plan |
| Verify | Proof on the pull request a reviewer can rerun |
| Watch | A green pipeline. The agent does not merge |
| You merge | The repo's merge rule decides who clicks merge |
| Monitor | A read-only watch after deploy. Say `/monitor` |

Work does not skip a station because the agent feels sure. Agree before building. Tests describe what a person sees. The proof lives on the pull request.

Station manuals and every other name: [skills/CATALOG.md](skills/CATALOG.md).

## On a machine

| Goal | Do |
| --- | --- |
| Rules on your own machine | [AI-setup](AI-setup/README.md) |
| This line in another repo | `skills/setup-repo/scripts/detect-repo.sh <repo>`, then `bootstrap.sh <repo>` |

Operator manual: [AGENTS.md](AGENTS.md). Rules: [rules/](rules/README.md).

[![License: MIT](https://img.shields.io/badge/license-MIT-2F9E8F)](LICENSE)
