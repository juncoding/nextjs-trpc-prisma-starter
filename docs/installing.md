# Installing this plugin

`nextjs-trpc-prisma-starter` is a [Claude Code plugin](https://docs.claude.com/en/docs/claude-code/plugins). It contributes skills and slash commands to Claude Code; it doesn't itself need to be a Node project (and isn't).

## Option 1: install from GitHub

Once the repo is published to GitHub, reference it in your Claude Code config.

In `~/.claude/settings.json` (user-level) or `.claude/settings.json` (project-level):

```json
{
  "plugins": {
    "nextjs-trpc-prisma-starter": {
      "source": "github:juncoding/nextjs-trpc-prisma-starter"
    }
  }
}
```

Restart Claude Code. The skills and commands will be available.

## Option 2: install from a local clone

Clone the repo:

```bash
git clone https://github.com/juncoding/nextjs-trpc-prisma-starter ~/Dev/nextjs-trpc-prisma-starter
```

Point Claude Code at the local path:

```json
{
  "plugins": {
    "nextjs-trpc-prisma-starter": {
      "source": "/Users/you/Dev/nextjs-trpc-prisma-starter"
    }
  }
}
```

Local installs pick up edits immediately — useful while iterating on the plugin itself.

## Option 3: copy a single skill into a project

If you only want one piece (e.g. just the `architecture-patterns` reference for an existing project), copy that skill folder into your project's `.claude/skills/`:

```bash
cp -r ~/Dev/nextjs-trpc-prisma-starter/skills/architecture-patterns .claude/skills/
```

Claude Code picks up project-local skills automatically.

## Verification

After install, in a fresh Claude Code session:

1. Type `/scaffold-tool` — the command should autocomplete.
2. In conversation: "scaffold a new internal tool" — the `scaffold-internal-tool` skill should be offered.
3. In an existing project on this stack: "how do I add a new tRPC procedure?" — `architecture-patterns` should be offered.

If any of those don't work, your `settings.json` is probably wrong or you need to restart Claude Code.

## Updating

If you installed from GitHub, Claude Code refreshes the plugin on each session start. If from a local clone, `git pull` in the repo and restart Claude Code.

## Uninstalling

Remove the entry from `settings.json` and restart. The plugin contributes no files to your project repo — it only adds skills/commands to your Claude Code session.
