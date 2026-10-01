# SharePoint Issue Status

Source reviewed: **Share point integration issues.docx** (23 Sep 2026). This is a short comparison of that assessment with the current repository and latest org evidence. `Resolved` means code evidence exists. “Verified” means it was demonstrated in the current org.

## Important current state

- The latest full test run passed: **1,301 / 1,301**; org-wide coverage was **87%**.
- Microsoft Graph authentication was verified in the current org: `GRAPH_ACCESS=SUCCESS`, with 1,623 items found under the configured Accounts parent folder.
- The latest local changes (platform-event fallback, insert-only folder trigger, permission-set expansion, Box retirement, failure notification, and resized logo) must still be deployed and validated in the org.
- The Account backfill check returned 50 incomplete Accounts (the query was limited to 50). Wait for the batch/Queueable jobs to finish and rerun the count query before declaring backfill complete.
- The `CustomNotificationType` metadata file was removed because the installed Salesforce CLI cannot deploy that type from source. Create the notification once in Salesforce Setup before testing C8.

## Current test status

| Check | Current status |
| --- | --- |
| Apex tests | **1,301 / 1,301 passed** |
| Org-wide Apex coverage | **87%** (above the 75% deployment minimum) |
| Test-run coverage | **88%** |

## Deploy blockers

| Issue | Status | Current resolution / action |
| --- | --- | --- |
| B1 - missing folder-service test override | Resolved | `SharePointFolderService.configOverride` and its test-aware getter exist. |
| B2 - missing folder-readiness method | Resolved | `LinkEaseController.getFolderReadiness` and its test exist. |
| B3 - low SharePoint coverage | Resolved | Current org coverage is 87%; production validation still decides final coverage. |
| B4 - external credential missing from source | Resolved / verified in current org | `SharePoint_Graph` authenticated to Microsoft Graph and listed the configured Accounts parent folder successfully on 25 Sep 2026 (`CHILD_COUNT=1623`). Re-run this read-only check in Production after deployment. |

## Critical and high issues

| Issue | Status | Current resolution / action |
| --- | --- | --- |
| C1 - only first upload succeeds | Resolved | One upload is processed per Queueable; DML happens after callouts. |
| C2 - endless folder/upload chain | Resolved | Folder deferrals are capped at 3, then failures are recorded. |
| C3 - folders beyond Graph page one missed | Resolved | Graph folder lookup and listing follow `@odata.nextLink`. |
| C4 - heap/callout limits for large or many files | Resolved | One file per job; simple uploads are limited to 4 MB; larger files publish an event for middleware. |
| C5 - queueable-limit save failure | Implemented; deploy/test pending | When no Queueable slot is available, folder and file work is published as platform events and re-enqueued asynchronously. |
| C6 - existing Account edits can start work | Implemented; backfill verification pending | Folder creation now runs only after Account insert. Existing Accounts are handled by the controlled reconciliation batch. |
| C7 - new yearly Account folders | Resolved / accepted | New yearly folders are the intended behaviour; stored IDs continue to route current uploads correctly. |
| C8 - errors only in debug logs | Implemented; setup/deploy/test pending | Failures set/create a `SharePoint_File_Link__c` record with `Failed`, create an error record, and send an in-app notification to active administrators after the `SharePoint_Integration_Failure` custom notification type is created in Salesforce Setup. |
| C9 - deletion sync never catches up | Resolved | First sync requests Graph `delta?token=latest`; cursor is persisted. |
| C10 - deletion sync cannot see private mappings | Resolved | Deletion sync and link service run `without sharing`. |

## Security issues

| Issue | Status | Current resolution / action |
| --- | --- | --- |
| S1-S4 - browser-supplied item/folder IDs allow cross-record access | Resolved | Controller verifies complete item ancestry under the record Account folder; uploads derive allowed folders server-side. |
| S5 - browser-controlled upload URL | Resolved | Upload URL is stored in `SharePoint_Upload_Session__c`; only its owner can use the session. |
| S6 - chunk path skips size/type checks | Resolved | Upload-session creation enforces 50 MB and blocked-extension checks. |
| S7 - integration permission set incomplete | Implemented; assignment/test pending | Permission set now includes principal, class, object, and SharePoint Account/Contract field access. Assign and test it in the target org. |

## Medium and low issues

| Issue | Status | Current resolution / action |
| --- | --- | --- |
| M1 - duplicate file names overwrite | Resolved | LinkEase direct/session uploads now use Graph `rename`, so same-name uploads are retained as separate files rather than overwriting prior content. |
| M2 - deleting one contract copy unlinks Salesforce file | Resolved | Link removal waits until no active copy remains. |
| M3 - large contract upload skips central copy | Resolved | A session is created for every target folder. |
| M4 - authentication error appears as not found | Resolved | Folder and URL lookups return null only for 404; other errors throw. |
| M5 - legacy Box triggers overlap | Implemented; deploy/test pending | `AccountFolder` and `BoxFiles` no longer invoke Box code; SharePoint owns these trigger paths. |
| M6 - async config difficult to test | Resolved | Jobs use the folder-service test-aware configuration getter. |
| M7 - duplicate LinkEase page components | Not in current source | No FlexiPage metadata is present in `force-app`; check deployed Production pages separately. |
| M8 - test hardcodes a year | Resolved | Current test no longer contains the cited hardcoded folder name. |
| L1 - unused `createAccountFolders` | Implemented; deploy/test pending | The unused immediate-save helper was removed; Queueable folder processing uses `resolveAccountFolderUpdate`. |
| L2 - duplicated blocked-extension lists | Implemented; deploy/test pending | LinkEase now reuses the Graph client's shared restricted-extension list. |
| L3 - URL parsing assumes `.com` | Resolved | Named-credential endpoint conversion now finds the URL path generically. |
| L4 - unnecessary global scheduler / catch | Resolved | Scheduler is now `public`; no cited catch remains. |
| L5 - oversized logo | Implemented; deploy/test pending | Logo was resized from 1254 px to 256 px square (about 689 KB to 49 KB). |

## Production items that code cannot prove

- Re-run the successful Graph-access check in Production after deployment; confirm Entra consent and external-credential principal assignment.
- Populate the `Default` `SharePoint_Config__mdt` record with Production drive and folder IDs; never secrets.
- Confirm any required allow-list/Remote Site configuration for SharePoint upload-session hosts.
- Assign `SharePoint_Integration_Access` and verify actual user permissions.
- Schedule deletion sync, run controlled Account backfill, and monitor Queueable/Apex Job and error records.
- Confirm Account `Nick_Name__c`, Contract `Type_of_Contract__c`, and the intended `Contracts` versus `Legal Contracts` folder design exist in Production.

## One-time Salesforce Setup for C8 notifications

1. In **Setup**, search for **Custom Notifications** and click **New**.
2. Create a notification with name **SharePoint Integration Failure**.
3. Confirm its API name is exactly `SharePoint_Integration_Failure`.
4. Enable Desktop and Mobile delivery, if those options are available, then save.

The Apex code finds this notification by API name and sends it to active users with administrator-level access whenever a SharePoint upload fails. The notification type is intentionally configured in Salesforce Setup rather than deployed from this repository.

## Sandbox deployment order

1. Create the C8 custom notification above.
2. Validate without saving changes:

   ```powershell
   sf project deploy start --source-dir force-app --dry-run --test-level RunLocalTests --wait 60
   ```

3. If validation succeeds, deploy the same source to the sandbox:

   ```powershell
   sf project deploy start --source-dir force-app --test-level RunLocalTests --wait 60
   ```

4. Assign `SharePoint_Integration_Access`, complete the Account backfill, and test the SharePoint upload/failure paths before Production.
