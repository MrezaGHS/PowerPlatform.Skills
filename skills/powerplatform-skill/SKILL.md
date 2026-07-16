---
name: powerplatform-skill
description: >-
  Build Microsoft Power Apps canvas apps on SharePoint and Power Automate, as code.
  Use this whenever the user wants to create, build, extend, or debug a Power App,
  canvas app, or an internal business process portal (multi step workflows, approvals,
  document folders, notifications, dashboards, audit locks) on standard Microsoft 365
  licensing without Dataverse. Trigger it for phrases like "build a power app",
  "create a canvas app", "add a screen or flow to my Power App", "unpack or pack an
  msapp", "why does pac canvas pack fail", "my Power Fx has an error", "design my
  SharePoint lists for an app", or when working in a repo with pa.yaml files or a
  powerapps folder. Prefer this skill even when the user does not say pa.yaml. If the
  target is a canvas app or a Power Automate flow, this is the way we build it.
---

# Power Platform builder

This skill turns the docs in this repo into a working build method. The numbered docs are the knowledge. This file is the router and the operating contract.

## How to work

1. Find the docs first. The numbered docs (01 to 13) and README.md live at the plugin root, one level above this `skills/` folder. Every doc named below is there. README.md has the doc map. 01_PLATFORM_MAP.md has the stack and the five bucket map of what is code versus what is manual clicks. Never promise in code what belongs to a clicks bucket.
2. Load the doc that governs the task before writing anything:

| Task | Doc |
|---|---|
| Write or edit pa.yaml, pack, import | 03_SOURCE_WORKFLOW.md |
| Any Power Fx formula | 06_POWERFX_RULES.md (22 rules, non negotiable) |
| Design or change SharePoint lists | 04_SHAREPOINT_DATA.md |
| App shell, OnStart, OnVisible, naming | 05_APP_ARCHITECTURE.md |
| Steppers, gates, shared panels, dashboards | 07_UI_PATTERNS.md |
| Approvals, cycles, permissions | 08_APPROVALS_PERMISSIONS.md |
| Power Automate flow JSON | 09_FLOWS.md |
| Specs for the human's manual work | 10_MANUAL_STEPS.md |
| Plan a whole new app | 11_BUILD_PLAYBOOK.md |
| Set up the AI collaboration itself | 12_WORKING_WITH_AI.md |
| Any error message | 13_TROUBLESHOOTING.md first, it is probably listed |

3. Deliver complete, paste ready formulas labeled with control and property. State exactly where every new variable is set. Never hand the user a fragment to merge.

## Hard rules (summary, details in the docs)

1. Respect the one way door. Before writing YAML meant for `pac canvas pack`, confirm the app has no Studio only controls (people picker combos, attachment forms). If it does, packing fails app wide (PA2108) and the workflow is Studio plus mirror. Never advise packing an app past the door.
2. The human does the clicks. SharePoint sites, lists, columns, permissions, connections, flow skeletons, imports, sharing, Studio only controls. Write them exact specs, and track pending manual work in a STUDIO_TODO.md.
3. Confirm before mirror. Code goes to the human first, gets confirmed working in Studio, and only then is mirrored into the repo and committed.
4. Choice columns drift. Before coding against a Choice column's values, ask the user to paste the current values from SharePoint settings.
5. One writer per column. Before adding any Patch or flow action, check who owns the column. Never create a second writer.
6. State lives in SharePoint. UI variables are mirrors rehydrated in OnVisible. Every patch re-fetches the record and stamps `Last_Updated_On`. Cycle scoped queries always filter on the current cycle.
7. Redact anything shareable. Alias company name, role titles instead of people names, placeholder tenant URLs and GUIDs. Verify with a grep before committing.
8. Keep the docs honest. A new gotcha earned on a real build gets added to the matching doc the same session. When reality contradicts a doc, fix the doc.

## How this ships

This repo is a Claude Code plugin. This skill lives under `skills/`, and the numbered docs it routes to sit at the plugin root. Install it from GitHub with the two commands in README.md, then it triggers on Power Apps work on any Claude plan. To feed the docs to a different AI tool instead, use the instructions template in 12_WORKING_WITH_AI.md.
