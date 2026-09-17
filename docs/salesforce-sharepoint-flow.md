# Salesforce and SharePoint Integration Flow

This diagram explains how Salesforce records and files are synchronized with SharePoint through Microsoft Graph. It is intended as a manager-facing overview of the implementation and its operational controls.

For the detailed deployment, validation, and troubleshooting runbook, see [salesforce-sharepoint-integration.md](salesforce-sharepoint-integration.md).

## End-to-end flow

```mermaid
flowchart LR
    subgraph SF[Salesforce]
        A[Account inserted]
        AT[SharePointAccountFolder trigger]
        AC[Account record]
        CDL[ContentDocumentLink inserted]
        FT[SharePointFiles trigger]
        FH[SharePointFileTriggerHandler]
        CV[Latest ContentVersion]
        LWC[LinkEase LWC]
        JOBS[Apex Jobs and debug logs]
        MAP[SharePoint_File_Link__c mapping]
        DEL[Matching ContentDocumentLink]
        DOC[Salesforce ContentDocument]
    end

    subgraph AP[Apex integration layer]
        FJ[SharePointFolderCreationJob\nQueueable: up to 30 Accounts]
        FS[SharePointFolderService]
        UJ[SharePointUploadJob\nQueueable: up to 100 uploads]
        ROUTE[Resolve record and target folders]
        VALIDATE[Validate file\nlatest version, size, extension, folder ID]
        RETRY[Upload with retry\nup to 3 attempts]
        LE[LinkEaseController]
        DS[Scheduled SharePointDeletionSync]
    end

    subgraph GRAPH[Microsoft Graph boundary]
        NC[Salesforce Named Credential\ncallout:SharePoint_Graph]
        AUTH[External Credential\nMicrosoft identity and consent]
        API[Microsoft Graph API]
        DELTA[Drive delta API]
    end

    subgraph SP[SharePoint]
        ROOT[Configured Accounts parent]
        ACCOUNT[Account folder\nname plus current year]
        CHILD[Contracts or Legal Contracts\nand Opportunities]
        DEST[File destinations]
        CENTRAL[Central contract folder\nCDA, LOI, MSA, CSA, QAA, review, or Misc]
        DIRECT[Direct LinkEase files\nno Salesforce File created]
    end

    A --> AT --> FJ --> FS
    FS -->|Read Default SharePoint_Config__mdt| NC
    FS -->|Find or create account folder| NC
    NC --> AUTH --> API
    API --> ROOT
    ROOT --> ACCOUNT --> CHILD
    FS -->|Save SharePoint folder IDs| AC

    CDL --> FT --> FH --> UJ
    UJ --> CV
    UJ --> ROUTE
    ROUTE -->|Account: account folder| DEST
    ROUTE -->|Opportunity: parent Account Opportunities folder| DEST
    ROUTE -->|Contract: Account contract folder| DEST
    ROUTE -->|Contract status and type| CENTRAL
    DEST --> VALIDATE
    CENTRAL --> VALIDATE
    VALIDATE -->|Valid| RETRY --> NC
    NC -->|Upload or replace file| API
    API -->|Uploaded DriveItem ID| MAP
    UJ -->|Skipped or failed work| JOBS
    RETRY -->|Final failure| JOBS

    LWC --> LE
    LE -->|List folders/files or upload directly| NC
    NC -->|Direct Graph operation| API
    API --> DIRECT
    LE -.->|Does not create ContentDocument or ContentDocumentLink| DOC

    DS --> DELTA
    DELTA -->|Deleted DriveItem IDs| DS
    DS --> MAP
    MAP -->|Remove matching link only| DEL
    DEL -.->|Salesforce ContentDocument remains| DOC

    AT -.->|Also starts separate legacy Box path| JOBS

    classDef salesforce fill:#e8f1fb,stroke:#1769aa,color:#102a43
    classDef apex fill:#fff3d6,stroke:#b7791f,color:#3d2b00
    classDef graph fill:#e9f7ef,stroke:#27864b,color:#12351f
    classDef sharepoint fill:#f5eafa,stroke:#7b3fa1,color:#281438
    classDef monitor fill:#fbe8e8,stroke:#b42318,color:#4a1515

    class A,AT,AC,CDL,FT,FH,CV,LWC,MAP,DEL,DOC salesforce
    class FJ,FS,UJ,ROUTE,VALIDATE,RETRY,LE,DS apex
    class NC,AUTH,API,DELTA graph
    class ROOT,ACCOUNT,CHILD,DEST,CENTRAL,DIRECT sharepoint
    class JOBS monitor
```

## How to explain the flow

1. **Account setup:** When an Account is created, Salesforce queues background work. Apex creates or finds the SharePoint Account folder and its child folders, then stores the returned SharePoint IDs on the Account.
2. **File synchronization:** When a Salesforce File is linked to an Account, Opportunity, or Contract, another queueable job reads the latest file version, resolves the correct SharePoint destination, validates the file, and uploads it through Microsoft Graph.
3. **Contract routing:** Contract files are copied to the Account contract folder and to a central folder selected from the Contract status and type, such as CDA, LOI, MSA, or a review folder.
4. **Direct user experience:** LinkEase can list and upload files directly to SharePoint. Those files intentionally bypass Salesforce Files and therefore do not create `ContentDocument` or `ContentDocumentLink` records.
5. **Deletion synchronization:** A scheduled job polls Microsoft Graph for deleted SharePoint items and removes only the matching Salesforce File link. It does not delete the underlying Salesforce File because that file may still be linked to other Salesforce records.

## Controls and operating model

- **Authentication:** Apex calls Microsoft Graph through the Salesforce Named Credential `callout:SharePoint_Graph`, backed by an External Credential. Secrets and access tokens are not stored in Apex or source control.
- **Configuration:** The integration reads drive, parent-folder, and central-folder IDs from the `Default` `SharePoint_Config__mdt` record.
- **Asynchronous processing:** The Salesforce transaction can finish before SharePoint work completes. Apex Jobs, debug logs, and SharePoint audit logs are therefore part of normal monitoring.
- **Scale controls:** Folder creation processes up to 30 Accounts per queueable. File processing handles up to 100 upload requests per queueable and chains remaining work.
- **File protection:** Files over 50 MB, files with missing content, and files with `exe`, `bat`, `cmd`, or `scr` extensions are skipped.
- **Reliability:** Uploads are attempted up to three times. Final failures are logged, but the current implementation does not create a durable error record or automatically replay them.
- **Duplicate names:** Microsoft Graph uses replace behavior for an existing file with the same name in the destination folder.

## Implementation references

- [SharePointAccountFolder.trigger](../force-app/main/default/triggers/SharePointAccountFolder.trigger) starts SharePoint Account-folder processing.
- [SharePointFolderCreationJob.cls](../force-app/main/default/classes/SharePointFolderCreationJob.cls) batches and chains Account folder work.
- [SharePointFolderService.cls](../force-app/main/default/classes/SharePointFolderService.cls) creates folders, stores IDs, and selects central contract destinations.
- [SharePointFiles.trigger](../force-app/main/default/triggers/SharePointFiles.trigger) starts Salesforce File processing.
- [SharePointFileTriggerHandler.cls](../force-app/main/default/classes/SharePointFileTriggerHandler.cls) filters supported records and groups links by document.
- [SharePointUploadJob.cls](../force-app/main/default/classes/SharePointUploadJob.cls) resolves destinations, validates files, retries uploads, and records mappings.
- [SharePointGraphClient.cls](../force-app/main/default/classes/SharePointGraphClient.cls) performs Microsoft Graph folder, file, listing, and delta operations.
- [LinkEaseController.cls](../force-app/main/default/classes/LinkEaseController.cls) handles direct SharePoint browsing and uploads.
- [SharePointDeletionSync.cls](../force-app/main/default/classes/SharePointDeletionSync.cls) performs scheduled deletion synchronization.

## Naming note

The current Apex implementation creates the Account child folder with the name `Contracts` in `SharePointFolderService.createAccountFolders`. The runbook and some routing documentation refer to this destination as `Legal Contracts`. Confirm the production SharePoint folder name before presenting the hierarchy as a fixed business standard or completing production sign-off.

The Box integration remains separate from this SharePoint flow. `AccountFolder.trigger` starts Box processing, while `SharePointAccountFolder.trigger` starts SharePoint processing.
