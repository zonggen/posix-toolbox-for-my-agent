# Tool Cheatsheet

## rg (ripgrep) — Content Search

```bash
rg "pattern"                        # basic search
rg "pattern" --type py              # only Python files
rg "pattern" --type-add 'scala:*.scala' --type scala  # custom type
rg "pattern" -g "*.test.ts"         # glob filter
rg "pattern" -g "!vendor/"          # exclude directory
rg "pattern" -m 5                   # max 5 matches per file
rg "pattern" -C 3                   # 3 lines context
rg "pattern" -A 10                  # 10 lines after match
rg "pattern" -l                     # file names only
rg "pattern" -c                     # count per file
rg "pattern" --json                 # JSONL output (one object per line)
rg -e "pat1" -e "pat2"             # multiple patterns (OR)
rg "pattern" -w                     # whole word match
rg "pattern" -i                     # case insensitive
rg "pattern" --multiline            # match across lines
rg "def \w+" --type py -o           # only matching part
```

## fd — File Discovery

```bash
fd "pattern"                        # find by name regex
fd -e py                            # by extension
fd -e py -e pyi                     # multiple extensions
fd -t f                             # files only
fd -t d                             # directories only
fd -d 3                             # max depth 3
fd --max-results 50                 # cap results
fd -H                               # include hidden files
fd -I                               # don't respect .gitignore
fd -E node_modules -E .git          # exclude dirs
fd --strip-cwd-prefix              # relative paths
fd "test" -e py --exec bat -r 1:5 {}  # exec per result
fd -e py --exec-batch wc -l         # exec once with all results
```

## bat — File Reading

```bash
bat file.py                         # full file with syntax highlighting
bat --plain file.py                 # no decorations (like cat)
bat -r 10:50 file.py                # lines 10-50 only
bat -r 10: file.py                  # from line 10 to end
bat -r :20 file.py                  # first 20 lines
bat -n file.py                      # line numbers only (no header/grid)
bat -l python script                # force language
bat -p -r 10:50 file.py             # plain + range (ideal for agents)
```

## eza — Directory Listing

```bash
eza                                 # ls replacement
eza -la                             # long format + hidden
eza --tree                          # tree view
eza --tree -L 3                     # tree depth 3
eza --tree --git-ignore             # respect .gitignore
eza --tree -L 2 --icons             # with icons
eza -la --sort=modified             # sort by modification time
```

## tokei — Code Statistics

```bash
tokei                               # summary table
tokei --output json                 # full JSON output
tokei --output json | jaq '.Python' # specific language
tokei -e tests -e vendor            # exclude dirs
tokei src/                          # specific directory
```

## sd — Find and Replace

```bash
sd 'old' 'new' file.py             # replace in file
sd 'old' 'new' *.py                # multiple files
sd -s 'old' 'new' file.py          # literal string (no regex)
sd 'foo(\d+)' 'bar$1' file.py      # capture groups
echo "text" | sd 'old' 'new'       # stdin
fd -e py | xargs sd 'old' 'new'    # bulk replace across files
```

## jaq — JSON Processing

```bash
jaq '.' file.json                   # pretty print
jaq '.key' file.json                # extract field
jaq '.items[]' file.json            # iterate array
jaq '.items[] | select(.age > 30)' file.json  # filter
jaq -r '.name' file.json            # raw string output
jaq -s '.' file1.json file2.json    # slurp into array
echo '{}' | jaq --arg k v '. + {($k): $v}'  # add field
cat data.jsonl | jaq -s '.'         # JSONL to array
```

## dust — Disk Usage

```bash
dust                                # current directory
dust -d 2                           # depth 2
dust -n 10                          # top 10
dust src/                           # specific directory
```

## just — Task Runner

```bash
just                                # list available recipes
just build                          # run recipe
just --list                         # list with descriptions
just --dry-run build                # show what would run
```

## git-delta — Diff Viewer

Configured via `~/.gitconfig`, not invoked directly:

```ini
[core]
    pager = delta
[delta]
    navigate = true
    side-by-side = true
```
