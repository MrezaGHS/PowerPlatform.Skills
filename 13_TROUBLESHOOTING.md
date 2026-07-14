# 13: Troubleshooting. Error to cause to fix

Every entry here happened on a real build. Search this page first, the exact message is usually listed. Deeper explanations live in the doc referenced per row.

---

## Build and toolchain

| Symptom | Cause | Fix | More |
|---|---|---|---|
| `'pac' is not recognized` | Fresh shell predates the CLI install's PATH change | Refresh PATH: `$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")`. Or install the CLI | 02 |
| `Authentication required` from pac | Token expired | Re-run `pac auth create --environment https://<org>.crm.dynamics.com` | 02 |
| `running scripts is disabled on this system` | PowerShell execution policy | `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser` | 02 |
| `pac canvas pack` fails with PA2108 (unknown property `SearchItems`) | The app contains a Studio only control (people picker combo, attachment form). The one way door is closed | Stop packing forever. Switch to the era 2 workflow: edit in Studio, export, unpack, commit | 03 |
| Pack succeeds but the imported app is full of formula errors | Pack validates structure, not Power Fx | Open the Formulas and errors panel in Studio after every import and clear every red | 03 |
| Import shows a "validate by opening in Studio" banner | Normal for a YAML packed app | Open it in Studio once | 03 |
| `git pull` rejected, remote contains work you do not have | Repo edited on GitHub directly | Run `git pull --rebase --autostash` on your branch before you push | 02 |
| A PR shows a giant unreadable diff | Binary msapp in git, or a full re-unpack | Gitignore the msapp binaries. Expect re-indentation noise in YAML diffs, write commit messages that describe the app change | 02, 03 |

## Power Fx, at author time

| Symptom | Cause | Fix | More |
|---|---|---|---|
| `Name isn't valid. 'r' isn't recognized` on an inline table field, plus cascading errors | A `Switch` or `If` branch returns a bare `Table()` so the row type loses the column | Type the default: `Table({ r: "" })` with the same columns as the real branches | 06 Rule 11 |
| Field names will not resolve inside `Concat`, `LookUp`, `ForAll` over an inline table | Missing row alias | Use `As`: `Concat(tbl As s, s.field, ...)` | 06 Rule 12 |
| `The name 'Value' is not recognized` on a text input | Modern TextInput read with the Classic property | Modern reads `.Text`, Classic reads `.Value`. Check the control family in the YAML | 06 Rule 13 |
| A Classic input silently returns empty string | Read with `.Text` instead of `.Value` | Same rule, the silent direction | 06 Rule 13 |
| `Circular dependency` on load, pointing at an HTML header | HtmlViewer references a control whose value depends back on the HtmlViewer | Compute the text in OnVisible into a variable, reference the variable | 06 Rule 16 |
| `The name 'varX' is not recognized` | Variable renamed or never set in OnStart | Set it in OnStart (full Set() line) or fix the reference. Keep a rename map when renaming | 05 |

## Power Fx, at run time

| Symptom | Cause | Fix | More |
|---|---|---|---|
| Generic `Network Error` on Patch | Raw string or number patched into a Choice or Lookup column | `{ Value: "..." }` for Choice, `{ Id: n, Value: "..." }` for Lookup, Person record for Person | 06 Rule 1 |
| `Incompatible Type` on Patch | Record variable initialized with `Blank()` | Initialize with `Defaults(List)` | 06 Rule 2 |
| `Invalid number of arguments: received 9, expected 7-8` on a flow `.Run` | The app cached an old flow signature | Studio, Power Automate pane, remove the flow, re-add it. Not a code bug | 06 Rule 19 |
| Flow call fails inside the app with no useful message | No error handling around `.Run` | Wrap in IfError with a toast, then check the flow run history in the portal | 06 Rule 20 |
| Second file upload sends the first file again, or `Duplicate File` error | `Reset()` used on the attachment control | `ResetForm()` on the parent form. `Reset()` only for the plain text inputs | 06 Rule 14 |
| Uploaded file row fails with `Invalid URL value` | Percent encoded long URL overflowed the 255 character Hyperlink column | In the flow, store `decodeUriComponent(first(split(url, '?')))` | 09 |
| Email folder link is dead for some clients | Client name contains `&` or an apostrophe and the link builder only replaced spaces | `EncodeUrlComponent()` app side, clean the name at save time | 06 Rule 21 |
| Notification email link opens the app but not the record | The play URL in the button is a placeholder, or the deep link handler is missing | Real play URL in the button, `Param("dealId")` handler in OnStart | 05, 10 |
| Clicking the stepper HTML does nothing | HtmlViewer cannot fire Power Fx | Real controls: a gallery of buttons, or transparent rectangles over the HTML | 06 Rule 15 |

## State and data

| Symptom | Cause | Fix | More |
|---|---|---|---|
| UI shows stale values after a Patch | Local record variable not re-fetched | `Set(varDeal, LookUp(Deals, ID = varDeal.ID))` after every patch | 06 Rule 3 |
| Saved state (a green confirmation, a substep) vanishes on reload | State lived only in a variable | Persist to a column, rehydrate the variable in OnVisible | 05, 06 Rule 5 |
| A previous cycle's approver shows up, or an old approval counts | Query or combo DefaultSelectedItems missing the cycle filter | Add `Review_Cycle = varDeal.Review_Cycle` to every step scoped query, including combo defaults | 06 Rule 8 |
| Yes/No logic misbehaves on old rows | Blank is not false | `Coalesce(field, false)` on every Yes/No read | 06 Rule 9 |
| Notification flag flips back and forth | App and flow both write the column | One writer per column. The app reads, the flow writes (or the reverse), never both | 06 Rule 6 |
| Refresh button does not surface new SharePoint rows | Gallery bound to a collection snapshot | Bind Items to the data source with inline filters, then `Refresh(source)` works | 07 |
| Two users overwrote each other's step move | Move button did not re-read before writing | Re-read the live record, compare, stop and refresh if it moved | 07 |
| Send button stays enabled after a successful send | Missing the unsent row count gate in DisplayMode | Add the `CountRows(... Notification_Sent <> true) > 0` gate | 07 |
| Send button permanently dead after a failed save | IfError catch did not reset the debounce gate | The catch must `Set(varSendNotification_Ready, true)` | 06 Rule 7 |

## Studio and environment

| Symptom | Cause | Fix | More |
|---|---|---|---|
| Every themed control renders black or blank in Studio | OnStart has not run this session | Tree view, App, Run OnStart. Required after any OnStart edit | 05 |
| `You don't have permission to do this` on Save | Missing Contribute on the SharePoint list | Fix SharePoint permissions, the app code is fine | 08 |
| A user cannot see a record in the browse view | Not on the record in any role, not an admin | Expected. Check the relevance gate | 08 |
| Admin cannot edit a step | By design, visibility is not authority | If truly needed, add the admin flag to that specific gate deliberately | 08 |
| Flow runs green but the folder or row is missing | Wrong site URL or list GUID in the action | Actions reference lists by GUID. Verify against the schema doc | 09 |
| Folder creation flow fails on re-run | `CreateNewFolder` errors when the folder exists | `runAfter` accepting Succeeded and Failed, plus the idempotency flag | 09 |
| Choice value patch silently does nothing or errors | The value drifted from what SharePoint actually has | Confirm current Choice values in SharePoint settings before coding against them | 04 |
| `WorkflowOperationParametersExtraParameter`, "no definition for parameter 'overwrite'", on trying to turn a flow on | The SharePoint `CreateFile` action retired the `overwrite` parameter | Delete `overwrite` from the action's parameters. Same name uploads now error instead of silently replacing, handle that explicitly | 09 |
| `InvalidTemplate`, `createArray` "invoked with no parameters" | `createArray()` called with zero arguments in a flow expression | `createArray()` needs at least one item. Seed with `createArray('')` and filter blanks from the result | 09 |
| A pasted people picker combo will not filter as you type a name | `SearchFields` carried over as `["Claims"]` instead of `["DisplayName"]` after copy paste | Open Advanced on the combo, set `SearchFields` to `["DisplayName"]` | 03 |

## When something is not listed

1. Read the exact error in the Formulas panel or the flow run history. The message is usually literal.
2. Check it against the rules in 06_POWERFX_RULES.md, most runtime surprises are one of the 22.
3. Reproduce it in isolation (one button, one patch).
4. When it is new and real, fix it, then add the row here. That is how this table got built.
