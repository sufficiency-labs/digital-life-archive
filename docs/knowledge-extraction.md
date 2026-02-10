# Knowledge Extraction Methodology

Process for mining archived data for structured knowledge: ideas, projects, and relationships.

## Overview

Archived digital life data (conversations, email, cloud files) is searchable but unstructured. This process extracts structured indexes:

1. **idea-index** — Every distinct idea, project, framework, or creative work
2. **relationships** — Every person and relationship context

Both exist as separate Git repositories with granular commit history (one commit per idea/person added or updated).

## Repository Setup

```bash
# Create private repositories
gh repo create USERNAME/idea-index --private
gh repo create USERNAME/relationships --private

# Add as submodules (if using parent monorepo)
git submodule add git@github.com:USERNAME/idea-index.git private/idea-index
git submodule add git@github.com:USERNAME/relationships.git private/relationships
```

### idea-index Structure

```
idea-index/
  README.md         # Repository overview and conventions
  CLAUDE.md         # Instructions for AI assistants
  INDEX.md          # Master index of all ideas
  SOURCES.md        # Processed data sources
  PROCESS.md        # This extraction methodology
  ideas/
    [idea-name]/
      README.md     # Summary, status, key concepts, cross-references
      SOURCES.md    # Documents mentioning this idea
      [sub-idea]/   # Optional nesting (maximum 3 levels)
```

### relationships Structure

```
relationships/
  README.md
  CLAUDE.md
  INDEX.md
  SOURCES.md
  people/
    [firstname-lastname]/
      README.md     # Relationship context, interactions, cross-references
      SOURCES.md    # Documents mentioning this person
```

## Extraction Methodology

### Phase 1: Survey and Cluster

Before document reading, scan titles/subjects to group related content into clusters:

```bash
# Conversations
ls conversations/openai/conversations/ | sort

# Email
notmuch search --output=summary '*' | head -100

# Cloud files
find cloud/dropbox/ -maxdepth 3 -type f | sort
```

Group documents by theme. Example clusters:
- "Machine Learning Research" — 15 conversations about ML techniques
- "Business Planning" — 8 conversations about startup ideas
- "Creative Writing" — 5 conversations about a novel

Processing by cluster (not chronologically) enables building each idea across all mentions before committing.

### Phase 2: Process Each Cluster

For each document in a cluster:

#### a) Read complete document

#### b) Extract ideas

Identify:
- **Named projects or ventures** — "Aristoi Institute", "startup idea"
- **Frameworks or methodologies** — "Bayesian Risk Modeling", "VDSE"
- **Business concepts** — "Post-Scarcity Software", "subscription model for X"
- **Creative works** — novels, games, applications, art projects
- **Research directions** — "recursive intelligence", "fairness in ML"
- **Sub-ideas** nesting under parent ideas

**Exclude:** Trivia questions, one-off lookups, current events discussion, recipes

#### c) Extract people

Identify:
- Real people with actual relationships
- Context: colleague, collaborator, friend, family, professional contact, mentor
- Discussion topics or collaborative work

**Exclude:** Public figures (politicians, CEOs, celebrities) without direct relationship. AI assistants are not relationships.

#### d) Determine structure

- **Nest** when clear parent-child relationship exists
- **Keep flat** when ideas are related but independent
- Maximum 3 levels of nesting for ideas; people always flat
- When uncertain, keep flat and use cross-references

### Phase 3: Create Files

#### New Idea

```bash
mkdir -p ideas/idea-name/
```

`ideas/idea-name/README.md`:
```markdown
# [Idea Name]
**Status:** Active | Dormant | Archived | Absorbed
**First seen:** [date]  |  **Last updated:** [date]

## Summary
[Idea description]

## Key Concepts
- [bullets]

## Current Status
[Current state]

## Next Steps / Open Questions
- [ ] [actionable items]

## Cross-References
- **Related ideas:** [relative links to other ideas]
- **Related people:** [relative links into relationships repo]
- **Subrepos:** [links to relevant code repos]
```

`ideas/idea-name/SOURCES.md`:
```markdown
# Sources: [Idea Name]

## ChatGPT Conversations
- `2025-04-01_Aristoi-Institute-AI-Pitch.md` — [brief note on conversation content]

## Email
- [thread subject] ([date]) — [brief note]

## Files
- `cloud/dropbox/path/to/file.pdf` — [brief note]
```

Commit:
```bash
git add ideas/idea-name/
git commit -m "Add idea: idea-name"
```

#### New Person

```bash
mkdir -p people/firstname-lastname/
```

`people/firstname-lastname/README.md`:
```markdown
# [Person Name]
**Context:** [colleague | collaborator | friend | family | professional contact | mentor]
**First mentioned:** [date]  |  **Last mentioned:** [date]

## Relationship Summary
[How person is known, collaborative work]

## Key Interactions / Topics
- [bullets]

## Cross-References
- **Related ideas:** [relative links into idea-index]
- **Related people:** [relative links to other people]
```

Commit:
```bash
git add people/firstname-lastname/
git commit -m "Add person: firstname-lastname"
```

#### Updates to Existing Entries

```bash
# Update SOURCES.md and/or README.md
git add ideas/idea-name/
git commit -m "Update idea-name: add source from [description]"
```

### Phase 4: Update Indexes

After cluster processing, update `INDEX.md` in both repositories:

```markdown
## Ideas
- [Aristoi Institute](ideas/aristoi-institute/) — Active — Non-profit AI for intellectual disabilities
- [Bayesian Risk Modeling](ideas/bayesian-risk-modeling/) — Active — Cybersecurity risk quantification
```

Commit: `"Update INDEX: add [cluster-name] ideas"`

### Phase 5: Track Processed Sources

Update `SOURCES.md` at repository root to track fully processed data sources. Include "Reviewed — no ideas" section for documents read but containing nothing extractable.

## Decision Rules

### Status Assignment

- **Active**: Recent discussion or stated continuation plans
- **Dormant**: Past discussion, no recent activity
- **Archived**: Explicitly abandoned or completed
- **Absorbed**: Merged into another idea (cross-reference absorbing idea)

### Naming Conventions

- **Idea directories:** kebab-case (e.g., `bayesian-risk-modeling`)
- **People directories:** `firstname-lastname` in lowercase kebab-case
- **Cross-references:** Always relative markdown links

### Nesting vs. Flat Structure

- Nest when clear parent-child relationship exists
- Keep flat when ideas are related but independent
- When uncertain, keep flat and use cross-references

## Processing Different Data Sources

### Conversations (ChatGPT, Claude, Slack, Discord)

- Each conversation is one document
- Scan title for cluster assignment, then read completely
- Most conversations mention 0-3 ideas and 0-2 people
- Some are pure trivia — mark as "reviewed, no ideas"

### Email

- Use `notmuch search` to find relevant threads by keyword
- Process by thread, not individual message
- Email often contains more relationship data than idea data

### Cloud Files (Dropbox, Google Drive)

- Scan directory tree and file names first
- Only read files appearing relevant (presentations, documents, spreadsheets)
- These often provide evidence for ideas first seen in conversations

## Commit Strategy

- **One commit per idea/person created or updated** — provides granular git history
- Commit messages follow pattern: `"Add idea: <path>"` or `"Update <path>: <what changed>"`
- Batch INDEX.md updates by cluster: `"Update INDEX: add <cluster> ideas"`

## Verification Checklist

After processing all documents from a data source:

- [ ] Every document appears in at least one SOURCES.md (idea, person, or "reviewed-no-ideas")
- [ ] INDEX.md in both repositories is complete and all links resolve
- [ ] `git log` shows granular per-idea/per-person commits
- [ ] No orphaned directories (every directory has README.md + SOURCES.md)
- [ ] Cross-references between repositories use correct relative paths

## AI Assistant Integration

This process functions with AI coding assistants (Claude Code, etc.):

1. **Cluster first** — Group documents by theme before processing
2. **Process in parallel** — Multiple agents can read different clusters simultaneously
3. **Merge results** — Deduplicate across agents (same idea may appear in multiple clusters)
4. **Review** — Human verification of AI-generated summaries for accuracy
5. **Iterate** — Execute process on new data sources, updating existing entries

Key insight: AI can read hundreds of documents rapidly and extract structured data. Human verification ensures accurate categorization and relationship mapping.
