# Output Budgeting

## Why Budget Output

Agent context windows are finite. Dumping 10,000 grep matches wastes tokens, drowns signal in noise, and can cause the agent to lose track of its task. Every tool call should return the minimum output needed to make a decision.

## Default Budgets

| Operation | Tool | Default budget | Flag |
| --- | --- | --- | --- |
| Content search | `rg` | 200 lines | `--budget 200` via smart_search.sh |
| File discovery | `fd` | 50 results | `--max-results 50` or `--budget 50` |
| Manifest file tree | `fd` | depth 3, 500 files | `--depth 3` via repo_manifest.sh |
| Per-file matches | `rg` | 5 per file | `-m 5` |
| Batch search | `rg` | 200 / N patterns | `--budget 200` divided evenly |

## When to Increase

- Searching for something rare (few expected matches)
- Need full context of a function/class definition
- Analyzing all usages of a specific API

## When to Decrease

- Broad exploratory search ("what files exist?")
- Pattern validation ("does this string appear anywhere?")
- Large monorepo with many matches

## Truncation Signals

All smart_search.sh modes report whether output was truncated:

```json
{
  "total_matches": 847,
  "budget": 200,
  "truncated": true
}
```

When `truncated: true`, narrow the search (add type filter, refine pattern) rather than increasing budget.

## Direct Tool Budgeting

When using tools directly without smart_search.sh:

```bash
# rg: limit matches per file
rg "pattern" -m 5 --type py

# rg: limit total output lines
rg "pattern" --type py | head -100

# fd: limit results
fd -e py --max-results 50

# fd: limit depth
fd -e py -d 3

# tokei: specific directory only
tokei src/ --output json
```
