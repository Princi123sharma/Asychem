# Salesforce–SharePoint Production Deployment Checklist

Use this checklist to deploy this project's Salesforce–SharePoint integration from a tested sandbox to Production. Record the release ID, date, owners, evidence, and result next to each item. Do not place client secrets, access tokens, Graph URLs containing tokens, or production item IDs in this document or source control.

## Release record

| Item | Record |
| --- | --- |
| Release / change ID |  |
| Planned deployment date and window |  |
| Salesforce deployment owner |  |
| Microsoft Entra / SharePoint owner |  |
| Business owner |  |
| Rollback decision-maker |  |
| Production org alias and org ID |  |
| Production tenant, site and document library |  |
| UAT evidence location |  |
| Deployment ID |  |

## Scope and exclusions

This checklist applies only to the implementation in this repository: Salesforce Account folder creation, Salesforce File uploads for Accounts, Opportunities and Contracts, the LinkEase SharePoint experience, SharePoint file-link mappings, and scheduled SharePoint deletion synchronization.

It does not authorize a data migration, a SharePoint permission-model redesign, or changes to the legacy Box integration. If Box automation remains installed, its coexistence or retirement must be explicitly approved before cutover.

## Production completion gate

Do not declare the release complete until every applicable item below is checked and its evidence is recorded in the release record.

- [ ] **Release readiness:** business approval, production ownership, change window, rollback decision-maker, large-file approach, UAT evidence, and the Box-retirement decision are complete.
- [ ] **Technical readiness:** final sandbox tests, deployable metadata, Production dependencies and limits, and a configuration restore point are verified.
- [ ] **Production configuration:** Microsoft Entra access, Salesforce credentials, custom metadata, Graph permissions, custom notification, and user permission-set assignments are configured and tested.
- [ ] **Validated deployment:** the Production dry run and the deployment of the exact validated source complete with `RunLocalTests`, required coverage, and no unresolved errors.
- [ ] **Controlled cutover:** Production Graph connectivity, folder creation, supported uploads and routing, deletion synchronization, large/invalid-file handling, multi-link behavior, and failure notification tests pass.
- [ ] **Backfill and schedules:** reconciliation/backfill completes, the two scheduled jobs exist exactly once, and the Production delta-sync state updates successfully.
- [ ] **Acceptance and handoff:** first-business-day hypercare is complete, LinkEase access is verified, the business owner accepts the release, and the release record contains all evidence and support contacts.
- [ ] **Rollback preparedness:** the containment and rollback plan has been reviewed, including the exact jobs, prior package, configuration values, and owners to use if needed.

## Release decision

- [ ] Business owner has approved the folder hierarchy and confirmed that the Account child folder must be named **Contracts** (the current Apex behavior), not **Legal Contracts**.
- [ ] The intended production tenant, SharePoint site, document library/drive, Accounts parent folder, and central contract folders are confirmed by their owners.
- [ ] A production change window, user communication, implementation owner, Microsoft Entra owner, Salesforce owner, and rollback decision-maker are identified.
- [ ] A tested plan exists for files over 4 MB. Trigger-driven Apex supports simple uploads only through **4 MB**; larger files must use the external streaming worker or the direct-browser LinkEase path.
- [ ] Sandbox/UAT evidence is attached: Account folder creation, normal upload, deletion sync, invalid-file rejection, multi-linked file behavior, and a forced failure/notification test.
- [ ] The deployment package contains only intended changes. Confirm whether legacy Box automation must remain available; the current SharePoint changes retire Box calls from the overlapping Account/File trigger paths.

## Pre-production technical readiness

- [ ] Run the full relevant Apex suite in the final sandbox and retain the result ID and coverage report. The recorded baseline is 1,301/1,301 tests passing with 87% org-wide coverage; Production validation is authoritative.
- [ ] Confirm all new/changed metadata is committed and deployable: Apex classes/tests, triggers, LWC, custom objects/fields, platform events, permission set, static resource, and any page assignments required for LinkEase.
- [ ] Compare Production metadata and dependencies. In particular verify Account `Nick_Name__c`, Account `SharePoint_*_Folder_Id__c` fields, Contract `Type_of_Contract__c`, `ContentDocumentLink`, and the SharePoint custom objects/event definitions exist and are usable.
- [ ] Review Production scheduled jobs, active batch jobs, queueable load, and platform-event limits. There must be no existing duplicate jobs with the names below.
- [ ] Create a restore point for configuration: export the current Production `SharePoint_Config__mdt` record, capture existing scheduled jobs, and retain the previous deployment ID/package for quick rollback. Do not export secrets into an unsecured file.

## Microsoft Entra and Salesforce configuration

- [ ] Register or confirm the Production Microsoft Entra confidential application for the selected tenant. Grant only the Microsoft Graph SharePoint permissions required for the intended drive and obtain tenant-admin consent.
- [ ] In Production, create/configure OAuth 2.0 External Credential `SharePoint_Graph_External`, including the identity provider, token endpoint, client ID, secret or certificate, and integration principal. Store the secret/certificate in Salesforce only.
- [ ] Create/configure Named Credential `SharePoint_Graph` with base URL `https://graph.microsoft.com`, callout access enabled, and External Credential `SharePoint_Graph_External` attached.
- [ ] Verify the permission set principal reference matches the Production principal: `SharePoint_Graph_External-SharePoint_Graph_Principal`. If the Production principal API name differs, update the permission set before deploying.
- [ ] Create or update the `SharePoint_Config__mdt` record with DeveloperName `Default`. Populate Production-only values for `Drive_Id__c`, `Accounts_Parent_Item_Id__c`, and each central Contract destination (CDA, LOI, MSA, CSA, QAA, Executive Review, Client Review, Internal Review, and Misc). Never add secrets to custom metadata.
- [ ] If central folder IDs are intentionally omitted, confirm the configured CRM root and the live `CRM / Legal Contracts / <type>` hierarchy; the code will look up those folders by name.
- [ ] Confirm SharePoint permissions allow the integration principal to list, create folders, upload/rename files, create upload sessions where used, and query drive delta changes—but only for the approved drive.
- [ ] Confirm Salesforce outbound-network policy/Remote Site configuration permits any upload-session host required by Microsoft Graph.
- [ ] In Salesforce Setup, create the custom notification named **SharePoint Integration Failure** and confirm the API name is exactly `SharePoint_Integration_Failure`. Enable desktop/mobile delivery as appropriate.
- [ ] Assign `SharePoint_Integration_Access` to every integration user (including the test user). Verify object, field, Apex class, and External Credential principal access using a non-System Administrator test user.

## Validate and deploy

- [ ] Authorize the Production org explicitly and verify the target alias/org ID before running any command.
- [ ] Run a Production validation deployment using the final source and `RunLocalTests`; resolve every error and review final code coverage.

```powershell
sf project deploy start --source-dir force-app --target-org <PROD_ALIAS> --dry-run --test-level RunLocalTests --wait 60
```

- [ ] Deploy the exact validated source, using the same target and test level. Record the deployment ID.

```powershell
sf project deploy start --source-dir force-app --target-org <PROD_ALIAS> --test-level RunLocalTests --wait 60
```

- [ ] Confirm deployment success and production aggregate Apex coverage of at least 75%; also confirm no trigger is left with zero coverage.
- [ ] Reconfirm the Production `Default` configuration and permission-set assignment after deployment; configuration and credentials are org-specific and not proven by the metadata deploy.

## Controlled cutover

- [ ] Perform a read-only Graph check through `SharePoint_Graph`: list the configured Accounts parent folder. Confirm an HTTP-successful response and that returned items are from the Production drive, not sandbox/test data.
- [ ] Create one clearly labelled test Account. Confirm its background job completes and the expected Account folder, `Contracts`, and `Opportunities` folders are created; verify the three SharePoint folder IDs are saved on the Account.
- [ ] Upload a permitted file below 4 MB to each supported target (Account, Opportunity, and Contract). Confirm SharePoint copies, expected folder routing, a `SharePoint_File_Link__c` record with successful status, and no duplicate overwrite for a same-named file.
- [ ] For a Contract, validate both its Account Contracts copy and the intended central-contract folder copy.
- [ ] Confirm unsupported extensions are rejected and a file over 4 MB follows the agreed worker/direct-upload path rather than silently failing.
- [ ] Link one Salesforce File to more than one supported record. Delete one SharePoint copy and confirm deletion sync removes only that mapping, not the Salesforce File or other active mappings.
- [ ] Force or safely simulate one upload failure. Confirm a failed link/mapping, a `SharePoint_Integration_Error__c` record, and the in-app custom notification are generated.

## Backfill and schedules

- [ ] Run the folder reconciliation/backfill in a small, controlled production window only after the new-Account test passes. Use the existing script or execute the batch at scope 20:

```apex
Database.executeBatch(new SharePointFolderReconciliationBatch(), 20);
```

- [ ] Monitor Apex Jobs until the batch and its queueables finish. Re-run the incomplete-Account query and retain the resulting count; investigate every Account with a missing SharePoint folder ID before declaring the backfill complete.
- [ ] Schedule deletion sync once (currently hourly). Do not create a second job if the stable job name already exists:

```apex
System.schedule('SharePoint deletion sync', '0 0 * * * ?', new SharePointDeletionSyncScheduler());
```

- [ ] Schedule upload-session cleanup once (currently hourly at minute 15):

```apex
System.schedule('SharePoint upload-session cleanup', '0 15 * * * ?', new SharePointUploadSessionCleanup());
```

- [ ] Verify both scheduled jobs in Setup. After the first deletion-sync run, confirm `SharePoint_Sync_State__c` record `Default` has the Production drive ID, a delta link, and an updated last-sync timestamp.

## Hypercare and acceptance

- [ ] Monitor Apex Jobs, failed queueables, debug/error logs, platform-event delivery, `SharePoint_Integration_Error__c`, and failed `SharePoint_File_Link__c` records during the first business day.
- [ ] Check that retries do not cause unexpected job growth; uploads retry up to three times and folder deferrals are capped at three.
- [ ] Confirm no unauthorised cross-record folder access is possible from LinkEase with the Production test user.
- [ ] Obtain business-owner acceptance after test folders/files are removed or clearly retained according to the agreed data policy.
- [ ] Document the final deployment ID, configuration owner, schedule IDs, Graph verification evidence, backfill result, known limitations, and support escalation contacts in the release record.

## Rollback / containment

Use containment first: pause user-facing uploads or unassign `SharePoint_Integration_Access`, then abort/unschedule only jobs created for this release if necessary. Do not delete SharePoint content or Salesforce mappings as a routine rollback action.

- [ ] If authentication or routing is wrong, remove the Production principal assignment or disable the relevant Named Credential access; preserve error evidence.
- [ ] If background work is unsafe, abort the specific batch/queueable where possible and unschedule only the identified `SharePoint deletion sync` and/or `SharePoint upload-session cleanup` jobs.
- [ ] If code must be reverted, deploy the previously validated package, restore the prior configuration values, and rerun focused validation before re-enabling access.
- [ ] Reconcile any files/folders created during the failed window with the SharePoint owner before resuming operations.
