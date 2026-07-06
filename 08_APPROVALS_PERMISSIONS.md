# 08: Approvals and permissions. The engine and the two layer access model

The approval engine and the access model are where governance actually lives. One proven design, with calibration options noted.

---

## The approval engine

### The data shape

One row per approver, per record, per review cycle, in the approvals list (04_SHAREPOINT_DATA.md). The record itself carries a cycle counter (`Review_Cycle`, starts at 1) and an overall status. That is the whole engine. Everything else is queries over it.

### Assigning approvers

Approvers come from the roles list, assigned by an explicit button, not as a side effect of a step move:

```
// btn_Assign OnSelect (route aware, typed default per 06_POWERFX_RULES.md Rule 11)
ForAll(
    Switch(varView,
        "FULL_FLOW", Table({ r: "President" }, { r: "COO" }, { r: "CFO" },
                           { r: "VP of Sales" }, { r: "Legal" }),
        "LIGHT_C",   Table({ r: "COO" }, { r: "CFO" }, { r: "VP of Sales" }),
        Table({ r: "" })
    ) As role,
    Patch(Approvals, Defaults(Approvals), {
        Deal: { Id: varDeal.ID, Value: varDeal.Deal_Reference },
        Approver_Role: { Value: role.r },
        Assigned_To: LookUp(Role_Config, Role_Name.Value = role.r).Assigned_To,
        Decision: { Value: "Pending" },
        Assigned_Date: Now(),
        Review_Cycle: varDeal.Review_Cycle,
        Notification_Sent: false
    })
)
```

Why a button and not the step transition: this was learned as a hard rule in production. The step 6 to 7 Next button only patches the record. The Save Approvers button on step 7 creates the review rows. Keeping row creation out of transitions means a transition can never half fail into duplicate reviewer rows, and approver assignment can be redone without moving the record.

Conditional approvers are data rules: on the lightweight routes the CFO row is added automatically when a concession exists (`Margin_Given_Up > 0`). Optional approvers (a PMO director) are simply rows that may or may not exist, and every "all approved" check adapts to whichever rows were assigned.

### Deciding

Each approver acts on their own row (the per row gallery in 07_UI_PATTERNS.md). Two decision actions only, Approve and Return (or Reject). The overall outcome flavor (approved, approved with conditions, approved as margin exception) is set once on the record by whoever finalizes, not per approver.

Parallel by default: all assigned approvers decide in any order, the record is approved when no non approved rows remain in the current cycle:

```
Set(varStep7_AllApproved,
    CountRows(Filter(Approvals,
        Deal.Id = varDeal.ID && Step_Number.Value = "7" &&
        Review_Cycle = varDeal.Review_Cycle &&
        Review_Status.Value <> "Approved")) = 0);
```

Sequential gates where needed: a governance variant lets directors approve in parallel but enables the executive's Approve button only after all assigned directors approved (compare approved director count against assigned director count, so the gate adapts when an optional director was skipped).

### The return loop and cycles

A return is the record moving backward with history kept:

1. The first Return bounces the record. Do not wait for the other approvers.
2. Remaining Pending rows of the cycle are auto closed (decision Rejected, with an auto comment like "Auto-closed due to a rejection in this cycle" so status surfacing can filter them out).
3. The cycle counter on the record increments by one.
4. The record's step moves back to the fix point (intake or drafting), with the return reason stored on the record.
5. Resubmission assigns fresh approver rows under the new cycle number.

Because every query filters on the current cycle, the new round starts clean while the full history of prior cycles stays for audit. A manual "reset cycle" button (senior roles only) covers the case where approvers were assigned wrongly before anyone decided.

Two engineered details that look small and are not. Undo: after approving, an Undo button shows while the round is open, it flips the row back to Pending and clears `Reviewed_On` back to blank. Close: distinct from Return, a senior only action that permanently closes a dead record as cancelled with a reason. Returns mean fix and resubmit, Close means dead.

### Notifying approvers

Approvers do not poll the app. A flow emails each pending approver of the current cycle with the record summary and two deep links (the app with `dealId`, the folder). The recipients come from the pending rows:

```
Set(varApRecipients,
    Concat(
        Distinct(
            Filter(Approvals,
                Deal.Id = varDeal.ID &&
                Review_Cycle = varDeal.Review_Cycle &&
                Decision.Value = "Pending"),
            Lower(Coalesce(Assigned_To.Email, ""))
        ) As p, p.Value, ";"));
```

`Distinct` matters: one person holding two roles gets one email. The debounce and auto grey pattern (07_UI_PATTERNS.md) wraps the Send button. The upgrade path when executives will not open any app: Microsoft Approvals cards in Teams, sent per approver by the flow, with the decision written back to the row. Design for it from the start by keeping one row per approver.

## The two layer access model

### Layer 1: SharePoint permissions. The real security.

List and folder permissions decide what a person can actually read or change. If the app shows a button but the user lacks Contribute on the list, the Patch fails with a permission error. The baseline grid:

| Asset | Typical grant |
|---|---|
| Main record list | Contribute for everyone who works records |
| File index list | Contribute (flows write here as the invoker) |
| Approvals list | Contribute for anyone who can be assigned a review |
| Roles list | Read for everyone, Contribute for admins only |
| Document library | Read on the library, Contribute on folders for uploaders |
| Confidential subfolder (financial analysis) | Locked to finance, the executive approvers, admins |

The most common "bug" in production is not a bug: a user gets "you don't have permission to do this" on Save, and the fix is SharePoint permissions, not app code. Check SharePoint first, always.

Confidentiality is enforced here, not in the app. The financial analysis subfolder and the margin columns are the sensitive zone: finance, the executives, and admins. Sales sees the price they entered, never the margin breakdown. Legal sees documents for legal review, not the money. If the app ever leaked a control by mistake, SharePoint still blocks the data.

### Layer 2: app gates. UX, not security.

Inside the app, gates decide what renders and what is enabled. They prevent confusion and accidents. A user with list Contribute could bypass the app entirely, so never treat an app gate as a security boundary.

The standard edit gate shape, computed in OnVisible per step:

```
Set(varStep5_CanEdit,
    !IsBlank(varDeal) &&
    !Coalesce(varDeal.Is_Locked, false) &&
    (
        varUserEmailLower = Lower(Coalesce(varDeal.Sales_Owner.Email, "")) ||
        varUserEmailLower = Lower(Coalesce(varDeal.Lead_Architect.Email, "")) ||
        varUserEmailLower = Lower(Coalesce(varPMODirector.Email, "")) ||
        (!IsBlank(varDeal.Project_Manager) &&
         varUserEmailLower = Lower(Coalesce(varDeal.Project_Manager.Email, "")))
    ));
```

Note the lock term: once locked, even authorized editors lose write access. Every edit gate carries it.

### Who sees which records

Two scopes, computed once and reused:

```
// global scope: admins and global role holders see everything
Set(varIsAdminOrGlobalRole,
    !IsBlank(LookUp(Role_Config, Role_Name.Value = "Admin"
        && Lower(Assigned_To.Email) = varUserEmailLower))
    || varUserEmailLower = Lower(Coalesce(varServicesDirector.Email, ""))
    || varUserEmailLower = Lower(Coalesce(varPMODirector.Email, ""))
    || varUserEmailLower = Lower(Coalesce(varCOO.Email, "")));

// per record relevance: on the record in any capacity
Set(varIsRelevantToDeal,
    !IsBlank(varDeal) && (
        varIsAdminOrGlobalRole ||
        varUserEmailLower = Lower(Coalesce(varDeal.Sales_Owner.Email, "")) ||
        varUserEmailLower = Lower(Coalesce(varDeal.Lead_Architect.Email, "")) ||
        varUserEmailLower = Lower(Coalesce(varDeal.Project_Manager.Email, "")) ||
        /* ... each working SME person column ... */
        CountRows(Filter(Reviews, Deal.Id = varDeal.ID &&
            Lower(Assigned_To.Email) = varUserEmailLower)) > 0));
```

Browse galleries filter on these: regular users see the records they are on, global roles see all.

### The admin philosophy (non negotiable)

Elevated visibility is not elevated authority. `varIsAdminOrGlobalRole` grants exactly three things: see all records in the browse views, see all reviews, and use the reset cycle button. It does not appear in step edit gates, it does not bypass evidence gates, it does not approve on anyone's behalf. Admins inside a record work under the same gates as everyone else. Any future feature that needs admin access references the flag explicitly in its own gate. Never make it a global bypass.

### Locking

The end of every record is a lock. `Is_Locked: true` plus `Locked_By` and the archive date, behind a confirm. Every edit gate and every flow respect it. Two calibrations proven in production:

- Hard lock: permanent, unlocking requires IT touching SharePoint directly. For audit grade records.
- Soft lock: anyone on the record, the approvers, or an admin can lock, an Undo appears right after, who locked is recorded (who unlocks is not). For processes where trust plus a record of who locked is enough.

Pick the calibration per process, deliberately, and write it down.

### Debugging permissions

| Symptom | Likely cause |
|---|---|
| Record missing from the browse view | User is on no role or reviewer row for it and is not a global role |
| "You don't have permission" on Save | Missing Contribute on the SharePoint list. Fix in SharePoint |
| Edit stays disabled for a just assigned person | Gate recomputes on OnVisible. Navigate away and back |
| Approve button disabled for an approver | Not their row, wrong cycle, or the record is locked |
| Combo shows last cycle's approver | Missing cycle filter in DefaultSelectedItems (06_POWERFX_RULES.md Rule 8) |
| Admin cannot edit a step | By design. Visibility, not authority |
