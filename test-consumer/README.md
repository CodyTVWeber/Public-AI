# Dummy validator

Scratch consumer for `public-ai-sync`. The AI folder `.public-ai/` is gitignored and filled on install.

## Steps

1. Install and confirm files land:

```sh
cd test-consumer
rm -rf .public-ai node_modules
npm install
test -f .public-ai/AGENTS.md
test -f .public-ai/rules/sample.md
test -f .public-ai/skills/demo/SKILL.md
grep -qxF '.public-ai/' .gitignore
```

2. Simulate a source change (version bump in a real consumer; here a fixture edit plus a second sync):

```sh
cp -a ai-source /tmp/pai-later
printf 'later\n' > /tmp/pai-later/rules/sample.md
printf 'extra\n' > /tmp/pai-later/rules/extra.md
rm /tmp/pai-later/skills/demo/SKILL.md
PUBLIC_AI_SYNC_SOURCE=/tmp/pai-later npx public-ai-sync
grep -qx later .public-ai/rules/sample.md
test -f .public-ai/rules/extra.md
test ! -e .public-ai/skills/demo/SKILL.md
```

3. Automated form of the same loop:

```sh
bash scripts/tests/public-ai-sync-consumer.test.sh
```

Automated tests live at the repo root, not in this folder.
