# 02: Environment setup. Tools, authentication, and the repo layout

One time setup for a Windows machine. After this, the daily loop is one command.

---

## Install

1. Git. https://git-scm.com/download/win
2. Power Platform CLI (`pac`). https://aka.ms/PowerPlatformCLI
3. VS Code (or any editor). VS Code is the viewer, diff tool, and search tool. It is not the app IDE, Power Apps Studio is.
4. Optional: GitHub CLI (`gh`) if you want to open and merge pull requests from the terminal.

## Configure git

Set your identity. Use a per repo identity (no `--global`) if you separate work and personal:

```powershell
git config user.name "Your Name"
git config user.email "you@yourcompany.com"
```

## Authenticate pac to your environment

```powershell
pac auth create --environment https://<yourorg>.crm.dynamics.com
```

Find the environment URL in the maker portal under Settings, Session details, or in the Power Platform admin center. The auth token expires from time to time. When any `pac` command says authentication required, re-run the same command.

## Windows gotchas that will bite on day one

| Symptom | Fix |
|---|---|
| `'pac' is not recognized` in a fresh shell | The installer updated PATH but the shell predates it. Refresh: `$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")` |
| `running scripts is disabled on this system` | `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser` |
| OneDrive sync fights git | Keep repos out of OneDrive. Use `C:\Users\<you>\source\repos\` |
| LF and CRLF warnings on every commit | Add a `.gitattributes` with `* text=auto` |

## The pac commands you will actually use

```powershell
# Canvas app, direct (before the one way door, see 03_SOURCE_WORKFLOW.md)
pac canvas list
pac canvas download --name "<App Display Name>" --file-name app.msapp --overwrite
pac canvas unpack --msapp app.msapp --sources src --layout SourceCode
pac canvas pack   --msapp built.msapp --sources src --layout SourceCode

# Solution (the app plus its flows, the long term container)
pac solution export --name <SolutionName> --path C:\temp\sol.zip --overwrite
pac solution unpack --zipfile C:\temp\sol.zip --folder <repo-folder>
pac solution pack   --zipfile C:\temp\sol_build.zip --folder <repo-folder>
```

Always use `--layout SourceCode` on canvas unpack. It produces the readable one file per screen YAML that diffs cleanly in git.

## One repo per app

Every app gets its own private GitHub repo. The layout that worked:

```
<AppName>/
  README.md                       the redacted front door
  sync.ps1                        one command commit and push (or export and sync)
  .gitignore
  .gitattributes                  * text=auto
  knowledgebase/                  numbered business and design docs (01_..., 02_...)
  mockup/                         the clickable HTML prototype, if the app had one
  powerapps/
    00_README.md ... 09_*.md      the app design docs (architecture, data model, steps,
                                  approvals, automation, access, build plan)
    SCHEMA_AS_BUILT.md            the real SharePoint list and column names
    app/
      app.ps1                     pull helper (download live app and unpack)
      src/                        canvas source: Src/App.pa.yaml, Src/scr_<X>.pa.yaml
      STUDIO_TODO.md              the manual steps log (see 10_MANUAL_STEPS.md)
    flows/
      <SolutionName>/             unpacked solution: Other/, Workflows/, CanvasApps/
  source_files/                   confidential originals. GITIGNORED, never pushed
```

The knowledgebase folder is what you upload to an AI assistant's project knowledge. Keep one topic per file, numbered. See 12_WORKING_WITH_AI.md.

## What gets gitignored

```gitignore
# OS and editor junk
.DS_Store
Thumbs.db
desktop.ini
.vs/
*.suo
*.user

# Office lock files
~$*

# Confidential source material, never publish
source_files/
mockup/logo.png

# Local only working files
00_PROJECT_SETUP.md
NEW_PROJECT_RUNBOOK.md

# Build artifacts, regenerated from source
powerapps/app/*.msapp
powerapps/flows/*_build.zip
powerapps/flows/*/CanvasApps/*.msapp
```

Two rules behind that list. First, binary `.msapp` files are build artifacts, the unpacked YAML is the source, so the binaries stay out (they add hundreds of KB per commit and diff as "binary file changed"). Second, anything confidential (original business documents, real logos) never enters git at all. The repo is written redacted from the start: company name replaced with an alias, people replaced with role titles. See 12_WORKING_WITH_AI.md for the redaction convention.

## The sync script

Every repo carries a `sync.ps1` so the daily loop is one command. Two variants exist, matched to the app's era (see 03_SOURCE_WORKFLOW.md):

Variant A, mirror sync (app is edited in Studio, repo mirrors it). The script pulls with `git pull --rebase --autostash`, runs `pac solution export`, `pac solution unpack`, `pac canvas unpack --layout SourceCode`, then commits and pushes. One command captures whatever changed in the cloud:

```powershell
.\sync.ps1 "Fix Step 5 reviewer count not updating"
```

Variant B, plain commit sync (docs and hand mirrored source). The script pulls, adds what you name to the commit (or everything), shows the list, asks to confirm, commits, pushes. Add a guard that refuses to run on `main` if the repo uses protected main plus pull requests:

```powershell
.\sync.ps1 "Update approvals doc" powerapps/05_APPROVALS.md
```

Both variants stop on the first failed step so nothing broken gets pushed. Commit per feature or fix, not one giant "multiple fixes" commit.

## Git discipline that proved worth it

- Protect `main` once the app is live. Require a pull request (zero approvals is fine when you work alone), block force pushes. Every change lands as one squash merged PR, so main reads one entry per finished piece of work.
- Commit messages describe the change in app terms ("Add validation to client name field"), because the YAML diff under it can be thousands of lines of re-indentation.
- The repo is the source of truth for history. The cloud is the source of truth for the running app. Know which direction sync flows in your current era (03_SOURCE_WORKFLOW.md) and never run a pull that overwrites hand authored source without a `-Force` style guard.
