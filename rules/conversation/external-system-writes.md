# External system writes

Writes to external systems (task trackers, issue and PR comments, chat, email, any third-party API that creates or updates content other people see):

| Step | Rule |
|---|---|
| Ask first | Propose the exact target and full payload; wait for explicit approval |
| Disclose agency | State the message is on behalf of the user; never imply the agent is the principal |
| One approval | One write per approval; ask again for each new external write unless the user pre-authorized that action in the same turn |

- Local-only work (repo files, local database) is out of scope; local git commits follow the repo's commit rules
- External reads need no approval