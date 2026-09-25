# SharePoint target-org setup

This repository deliberately does not contain Entra client secrets, production drive IDs, or access tokens.
Complete these steps in the target Salesforce org before enabling users.

1. In Microsoft Entra ID, register a confidential application for the selected tenant and grant only the Microsoft Graph SharePoint permissions required by the chosen drive. Obtain tenant-admin consent. Store the client secret or certificate in Salesforce only.
2. In Salesforce Setup, create an OAuth 2.0 External Credential named `SharePoint_Graph_External`. Configure the Microsoft identity provider, token endpoint, client ID, secret/certificate, and an integration principal.
3. Create a Named Credential named `SharePoint_Graph` with URL `https://graph.microsoft.com`, enable callout access, and connect it to `SharePoint_Graph_External`.
4. Add the external-credential principal to `SharePoint_Integration_Access`, complete the least-privilege Account, Contract, ContentDocumentLink, SharePoint mapping/error object permissions, then assign it to every integration user.
5. Create the `SharePoint_Config__mdt` record with DeveloperName `Default`. Populate the production drive ID, Accounts parent item ID, and each central Contract folder item ID. Do not put secrets in custom metadata.
6. Deploy source, execute `scripts/apex/runSharePointFolderBackfill.apex` in a sandbox first, validate the resulting folder IDs, then run it in production.
7. Execute `scripts/apex/scheduleSharePointDeletionSync.apex` once after deployment. Confirm the scheduled job exists in Setup.

## Large Salesforce Files

The trigger-driven Apex path safely supports simple Graph uploads up to 4 MB. Apex cannot safely stream a 50 MB `ContentVersion.VersionData` blob: asynchronous Apex has a 12 MB heap and Salesforce SOQL does not provide range reads for that blob.

To support larger Salesforce Files, deploy a streaming integration worker outside Apex. It must receive a Salesforce file event/reference, stream the ContentVersion through the Salesforce REST API, use Microsoft Graph upload sessions in 320 KiB-multiple chunks, then write the SharePoint mapping/error record back to Salesforce. Alternatively, redesign the user flow so the browser uploads direct to Graph through LinkEase; that does not create a Salesforce File automatically.
