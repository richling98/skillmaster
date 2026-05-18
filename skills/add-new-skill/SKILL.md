---
name: add-new-skill
description: Create a new SkillMaster skill in the local master folder and let the watcher sync it to supported AI tools.
---

# Add New Skill

Use this skill when the user wants to create a new reusable AI skill for SkillMaster.

## Workflow

1. Read `~/.skillmaster/config` to find `MASTER_DIR`.
2. Ask for the skill name if it is not already clear.
3. Create a folder at `$MASTER_DIR/<skill-name>/`.
4. Write the skill instructions to `$MASTER_DIR/<skill-name>/SKILL.md`.
5. Keep the skill focused: include a short YAML frontmatter block with `name` and `description`, then the instructions.
6. The SkillMaster watcher should sync the new skill to Claude Code and Codex automatically.
7. If the watcher is not running, run `scripts/sync.sh <skill-name>` from the SkillMaster repo.

## Skill Shape

```markdown
---
name: example-skill
description: A short explanation of when to use this skill.
---

# Example Skill

Instructions go here.
```

Do not place private credentials, API keys, or unrelated project files in a skill.
