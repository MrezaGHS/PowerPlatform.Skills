# 09: Power Automate flows. Anatomy, proven shapes, and the skeleton first method

Flows do the three jobs the canvas app cannot: create SharePoint folders, write files, and send email. This doc covers how flow JSON is structured, the flow designs that shipped, and the low error way to author new ones.

---

## Ground rules

- Trigger: PowerApps (V2) for every app called flow, in the same environment as the app.
- Connections: `shared_sharepointonline` (SharePoint) and `shared_office365` (Outlook, Send an email V2), running as invoker, so files and emails carry the identity of the person who clicked.
- One writer per column (06_POWERFX_RULES.md Rule 6). Flow written columns (`Folders_Created`, `Root_Folder_Url`, `Notification_Sent` flags) are read by the app, never written by it.
- Idempotency flags so a re-run never duplicates (`Folders_Created: true` written back after folder creation).
- Deep link every email: append `&dealId=<record id>` (and optionally `&view=<step>`) to the app play URL so the recipient lands on the exact record.
- Prefer reusable flows. An early build shipped six upload flows and three notification flows, one per document type or event. The next build collapsed those into one parameterized upload flow and one notification flow. Fewer flows, fewer places to fix.

## Trigger anatomy (PowerApps V2)

The trigger schema names inputs by type and order: `text`, `text_1`, `text_2`, ..., `number`, `file`. The designer shows friendly titles (ClientName, DealNumber), the JSON keeps the generic keys:

```json
"triggers": {
  "manual": {
    "type": "Request",
    "kind": "PowerAppV2",
    "inputs": {
      "schema": {
        "type": "object",
        "properties": {
          "text":   { "title": "ClientName",   "type": "string" },
          "text_1": { "title": "DealReference","type": "string" },
          "number": { "title": "RecordID",     "type": "number" },
          "file":   { "title": "File Content", "type": "object",
                      "properties": { "name": { "type": "string" },
                                      "contentBytes": { "type": "string", "format": "byte" } } }
        },
        "required": ["text", "text_1", "number"]
      }
    }
  }
}
```

The app's `.Run(...)` passes arguments positionally in the required array order, optional inputs (the file) last. Change the inputs and every app using the flow must remove and re-add it in the Power Automate pane (06_POWERFX_RULES.md Rule 19).

## Action anatomy

Every SharePoint action is an `OpenApiConnection` with the same skeleton:

```json
"Create_file": {
  "type": "OpenApiConnection",
  "inputs": {
    "parameters": {
      "dataset": "https://<tenant>.sharepoint.com/sites/<Site>",
      "folderPath": "@outputs('cmpTargetFolderPath')",
      "name": "@triggerBody()?['text_4']",
      "body": "@triggerBody()?['file']?['contentBytes']"
    },
    "host": {
      "apiId": "/providers/Microsoft.PowerApps/apis/shared_sharepointonline",
      "operationId": "CreateFile",
      "connectionName": "shared_sharepointonline"
    }
  },
  "runAfter": { "cmpTargetFolderPath": ["Succeeded"] }
}
```

The parts that must be exactly right:

- `dataset` is the site URL. `table` (for list actions) is the list GUID, not the list name. Record the GUIDs in the schema doc, changing a list means coordinated flow updates.
- `operationId` names the operation: `CreateNewFolder`, `CreateFile`, `GetFileItem`, `PostItem` (create list item), `PatchItem` (update list item), `GetItem`, `GetItems`.
- `connectionName` in `host` matches the key in the flow's `connectionReferences` block, which maps to a connection reference logical name shaped like `<publisherprefix>_shared<connector>_<hash>`. Reuse the existing connection reference for new flows, never invent one.
- Every action in a solution flow carries `"authentication": "@parameters('$authentication')"` inside its parameters (the examples above omit it for brevity, real flows must have it).
- `runAfter` chains actions. An empty `runAfter {}` marks the first action.
- Person columns are written as a claims string: `"item/Uploaded_By/Claims": "@concat('i:0#.f|membership|', triggerBody()?['text_5'])"`.
- Choice columns write through `/Value`: `"item/Folder_Category/Value": "05 Meeting Notes"`. Lookup columns through `/Id`: `"item/Deal/Id": "@triggerBody()?['number']"`.
- `Compose` actions (`"type": "Compose"`) are the workhorse for string building. Name them `cmp<What>` and read them with `outputs('cmpName')`.

Returning a value to the app makes the call synchronous and gives `.Run()` a result:

```json
"Respond_to_a_Power_App_or_flow": {
  "type": "Response", "kind": "PowerApp",
  "inputs": { "statusCode": 200,
    "body": { "folderpath": "@outputs('cmpFolderPath')" },
    "schema": { "type": "object",
      "properties": { "folderpath": { "type": "string" } } } }
}
```

The app reads it as `MyFlow.Run(...).folderpath`.

## Proven flow shape 1: create record folders

Called by the app right after a record is created. Actions in order:

1. Compose the folder name from customer plus reference: `{Customer} - {Reference}`. Trim the inputs. Clean characters SharePoint rejects.
2. Optional bucketing for scale: compose the first character of the client name, map it to a bucket folder (`1-9`, `A-C`, `D-G`, `H-K`, `L-P`, `Q-S`, `T-W`, `X-Z`) with nested `if()` expressions, and nest the record folder inside the bucket. Skip buckets until a folder actually gets crowded.
3. `CreateNewFolder` for the record folder, then one per subfolder (a fixed standard set per app, for example Checklist, Financial analysis, Supporting documents).
4. Optionally copy the route's blank checklist from a master Templates library into the Checklist subfolder (Copy file action). Masters are never edited, only copied.
5. `PatchItem` back onto the main list: `Folders_Created: true`, `Root_Folder_Url`, plus `Last_Updated_On`. Or skip the write back and return the path for the app to patch (see the caution below).
6. `Response` returning `folderpath`.

Hard learned notes:

- `CreateNewFolder` errors if the folder already exists. To tolerate re-runs, chain the subfolder actions with `runAfter` accepting `["Succeeded", "Failed"]`. `CreateFile` by contrast auto creates missing intermediate folders and never errors on existing ones, which is why upload flows do not need the folder to exist first.
- Decide the write back owner deliberately. If the flow patches `Folders_Created`, the app must not. One production flow skipped the update item action, so its app patches the flag client side after `.Run()`:

```
IfError(
    With({ result: CreateDealFolder.Run(varDeal.Customer, varDeal.Deal_Reference,
                                        varDeal.Route.Value, Text(varDeal.ID)) },
        Patch(Deals, varDeal, { Folder_Created: true, Folder_Link: result.folderpath })
    );
    Set(varDeal, LookUp(Deals, ID = varDeal.ID));
    Notify("Deal folder created.", NotificationType.Success),
    Notify("Could not create the folder. Check the flow run history.", NotificationType.Error))
```

## Proven flow shape 2: upload a file or register a link

One flow handles both a real file and a URL registration, branching on whether the link input is empty:

Inputs: ClientName, Reference, Subfolder (or FolderCategory), StepNumber, FileName, UploadedByEmail, RecordID (number), LinkUrl (text, empty means file), File (object, dummy `{ name: "Link.url", contentBytes: "" }` on the link path because the signature requires it).

File branch:

1. `CreateFile` into the composed target path with `@triggerBody()?['file']?['contentBytes']` as the body. Set chunked transfer (`"runtimeConfiguration": { "contentTransfer": { "transferMode": "Chunked" } }`) so large files work.
2. `GetFileItem` to fetch the new file's metadata.
3. Compose the document URL: `coalesce` the `Link to item`, `{Link}`, and `Path` properties, then `@decodeUriComponent(first(split(url, '?')))`. The split strips the query string, the decode un-escapes %20. Both are load bearing: SharePoint Hyperlink columns cap at 255 characters and percent encoded long names overflow and fail with "Invalid URL value".
4. `PostItem` a row into the file index list: name, URL, category, step, lookup to the record, uploader claims, `utcNow()`.

Link branch:

1. Compose a Windows shortcut body: `[InternetShortcut]` newline `URL=<the link>` newline `IconIndex=0` (build newlines with `decodeUriComponent('%0D%0A')`).
2. Compose the shortcut name, appending `.url` unless already present.
3. `CreateFile` the shortcut, `GetFileItem`, `PostItem` the index row with the real target URL as `Document_URL`.

So a registered link is both a real clickable `.url` file in the folder and a row in the index. The app calls the same flow for both paths:

```
// files: loop the attachment control
ForAll(att_Docs_Files.Attachments As f,
    UploadDocument.Run(varDeal.Customer, varDeal.Deal_Reference, varDeal.Route.Value,
        Coalesce(varUploadSub, "Supporting documents"), f.Name, User().Email,
        varDeal.ID, "", { name: f.Name, contentBytes: f.Value }));
// links: same flow, URL filled, dummy file
UploadDocument.Run(..., Trim(txt_LinkName.Text), User().Email, varDeal.ID,
    Trim(txt_LinkUrl.Text), { name: "Link.url", contentBytes: "" });
// then, always:
Refresh(Deal_Files); ResetForm(frm_Docs_Upload); Reset(txt_LinkName); Reset(txt_LinkUrl)
```

`ResetForm`, not `Reset`, on the upload form (06_POWERFX_RULES.md Rule 14).

## Proven flow shape 3: notify people

Two variants.

Simple recipients variant: the app computes a semicolon joined, deduplicated, lowercased recipient string (07_UI_PATTERNS.md and 08_APPROVALS_PERMISSIONS.md show the Concat and Distinct formulas) and the flow is just Send an email V2 to that string with subject, body, and the deep link. Inputs: RecordID, Reference, Customer, Recipients, AppLink. Start here.

Iterating variant (per row emails plus per row sent flags): the flow takes only RecordID and AppLink, does `GetItem` on the record and `GetItems` on the approval rows (`DealId eq {id} and Step_Number eq '7'`), then `Apply_to_each` row:

- Condition: the row has an email, belongs to the current cycle, and either was never notified or its stored context (a meeting date) changed since the last send.
- Send the email, addressing the person by their role with the underscores cleaned up, including the two deep links (app plus folder).
- `PatchItem` the row: `Notification_Sent: true`, `Notification_Sent_On: utcNow()`, plus the context that suppression compares against (the notified meeting date).

The suppression contract is shared with the app: the Send button's DisplayMode counts unsent rows with the same conditions, so the button greys exactly when the flow has nothing left to send, and re-arms when the date or person changes (07_UI_PATTERNS.md). PM style single recipients on the record use the same idea with flags on the record: `PM_Notification_Sent`, `PM_Notification_Meeting_Date`, `Last_Notified_PM_Email`, re-send when any differ.

Email body notes: a short delay (5 seconds) before the send lets SharePoint settle after row creation. Build folder links by encoding the path (simple replace of spaces with %20 breaks on `&` and apostrophes, prefer proper encoding or clean the names at save time).

## Proven flow shape 4: scheduled sweep

A daily recurrence trigger, `GetItems` with an OData filter (expiry date past, still active), one reminder email per hit. Used for ballpark estimate expiry reminders. Anything with a date column and a consequence can get one of these.

## The skeleton first method (how to author a new flow)

Hand authoring flow JSON from nothing fails on the invisible parts: GUIDs, connection references, the `$authentication` parameter on every action, exact SharePoint parameter formats. Some failures are silent until runtime. So never start from a blank file:

1. A human creates a skeleton in the Power Automate designer: the PowerApps V2 trigger with the inputs named and ordered, the connection wired to the existing connection reference, one placeholder action.
2. Export the solution (unmanaged) and unzip.
3. Author the real action logic by editing the flow's JSON. The trigger, connections, and auth boilerplate are now known good, and an existing flow in the same solution is the style reference for every action shape.
4. `pac solution unpack` the finished zip into the repo for version control, and import the solution back through the maker portal.

## Registering a flow in the solution by hand

When adding a flow JSON directly into an unpacked solution instead of through the designer:

1. Generate a new GUID for it.
2. Add `Workflows/<FlowName>-<GUID>.json` (the definition) and `Workflows/<FlowName>-<GUID>.json.data.xml` (the sidecar carrying the name, type, and state, copy an existing one and edit).
3. Add a root component to `Other/Solution.xml`: `<RootComponent type="29" id="{guid}" behavior="0" />` (type 29 is a cloud flow, type 300 is the canvas app).
4. Reuse the existing connection reference in the JSON's `connectionReferences` block.
5. `pac solution pack` and import.

This works and was done in production, but the skeleton first method above produces fewer surprises. Prefer it.

## Wiring the app to a flow

A `.Run()` only resolves after the flow is added to the app in Studio (the Power Automate pane). A YAML reference alone does not connect it, so the real `.Run()` wiring is part of the manual handoff (10_MANUAL_STEPS.md). The proven interim: have the button patch the flag directly (`Patch(Deals, varDeal, { Folder_Created: true })`) so the gates and downstream UI can be tested before the flow exists, then swap in the real call in Studio. And after any flow signature change: remove and re-add the flow in the pane, or you get the argument count cache error.
