# CLAUDE.md

This repo is a playbook for building Power Apps canvas apps on SharePoint and Power Automate, distilled from production builds. If you are an AI assistant working in or alongside this repo, this file is your operating contract.

## Before doing anything

Read [README.md](README.md) for the map. For any Power Platform task, load the docs that govern it first:

- Writing or editing pa.yaml, packing, importing: 03_SOURCE_WORKFLOW.md
- Any Power Fx formula: 06_POWERFX_RULES.md (the 22 rules are non negotiable)
- Designing or changing SharePoint lists: 04_SHAREPOINT_DATA.md
- App shell, OnStart, OnVisible, naming: 05_APP_ARCHITECTURE.md
- Steppers, gates, shared panels, dashboards: 07_UI_PATTERNS.md
- Approvals, cycles, permissions: 08_APPROVALS_PERMISSIONS.md
- Flow JSON: 09_FLOWS.md
- Planning a whole app: 11_BUILD_PLAYBOOK.md, and 01_PLATFORM_MAP.md for what is code versus clicks
- Any error: 13_TROUBLESHOOTING.md first, the exact message is probably listed

## Hard rules

1. Respect the one way door. Before writing YAML meant for `pac canvas pack`, confirm the target app has no Studio only controls (people picker combo boxes, attachment forms). If it does, packing fails app wide (PA2108) and the workflow is Studio plus mirror. Never advise packing an app that is past the door.
2. Full replacement standard. Deliver complete, paste ready formulas labeled with control and property. State exactly where every new variable is set. Never hand the user a fragment to merge.
3. The human does the clicks. SharePoint sites, lists, columns, connections, flow skeletons, imports, sharing, Studio only controls: these are the human's (10_MANUAL_STEPS.md). Write them specs, not promises. Track pending manual work in a STUDIO_TODO.md.
4. Confirm before mirror. In the paste driven loop, code goes to the human first, gets confirmed in Studio, and only then is mirrored into the repo and committed. Nothing unconfirmed lands in git.
5. Choice columns drift. Before coding against a Choice column's values, ask the user to paste the current values from SharePoint settings.
6. One writer per column. Before adding any Patch or flow action, check who owns the column and do not create a second writer.
7. Redaction. Anything that could be shared carries the alias company name, role titles instead of people names, and placeholder tenant URLs and GUIDs. Verify with a grep before committing.
8. Keep the docs honest. When a new gotcha or pattern earns its keep on a real build, add it to the relevant doc in the same session. When reality contradicts a doc, fix the doc.

## Writing style for docs in this repo

Plain and direct. No em dashes, no en dashes, no semicolons in prose (code blocks are exempt, Power Fx needs semicolons). Short sentences. Spell things out.
