# Session Coordination Protocol

When using AI assistants (Claude Code, etc.) to help manage your archive, this protocol prevents concurrent sessions from conflicting.

## Rules

### Every session MUST:

1. **On start:** Create `coordination/SESSION_<TIMESTAMP>.md` with:
   - What you're working on
   - Which files/submodules you'll modify
   - Your session status (ACTIVE)

2. **During work:** Update your session file when:
   - You change tasks
   - You start modifying shared files
   - You encounter blockers

3. **Before modifying shared files:** Check other active session files for conflicts.

4. **On end:** Mark your session as `STATUS: COMPLETE` with:
   - Summary of what was done
   - Files modified
   - Next steps

## Session file template

```markdown
# Session: YYYY-MM-DDTHH:MM:SSZ

**Status:** ACTIVE
**Working on:** [description of current task]

## Files being modified
- [list of files/directories this session will touch]

## What was done
- [running list of completed work]

## Next steps
- [what should happen next]
```

## Queued tasks

The `queued/` directory contains task starter packs. Each `.md` file is a self-contained briefing that a new session can pick up and execute.

### Task file format

```markdown
# Task: [Title]

**PRIORITY:** high | medium | low
**STATUS:** queued | in-progress | DONE
**ESTIMATED SCOPE:** [time estimate]

## Objective
[What needs to be done]

## Context
[Background information the session needs]

## Files to modify
[List of files/directories]

## Definition of done
[Clear criteria for completion]
```

### Lifecycle

1. Task created in `queued/` — available for pickup
2. Session picks it up, creates `SESSION_*.md`, references the task
3. On completion, session marks both files as COMPLETE/DONE
