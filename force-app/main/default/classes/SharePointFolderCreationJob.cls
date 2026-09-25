public with sharing class SharePointFolderCreationJob
    implements Queueable, Database.AllowsCallouts {

    private Set<Id> accountIds;
    // Present only when folder creation was initiated by a file upload. It
    // lets us resume that exact upload after the Account Contracts folder is
    // available.
    private Map<Id, Set<Id>> deferredUploads;
    private Integer deferredUploadAttempts;

    public SharePointFolderCreationJob(Set<Id> accountIds) {
        this(accountIds, null);
    }

    public SharePointFolderCreationJob(
        Set<Id> accountIds,
        Map<Id, Set<Id>> deferredUploads
    ) {
        this(accountIds, deferredUploads, 0);
    }

    public SharePointFolderCreationJob(
        Set<Id> accountIds,
        Map<Id, Set<Id>> deferredUploads,
        Integer deferredUploadAttempts
    ) {
        this.accountIds = accountIds == null ? new Set<Id>() : accountIds;
        this.deferredUploads = deferredUploads;
        this.deferredUploadAttempts = deferredUploadAttempts == null ? 0 : deferredUploadAttempts;
    }

    public void execute(QueueableContext context) {
        if (accountIds.isEmpty()) return;

        List<Id> pendingAccountIds = new List<Id>(accountIds);
        Id accountId = pendingAccountIds.remove(0);
        try {
            // All Graph calls complete before the Account update. This keeps
            // the transaction callout-safe while making the complete folder
            // structure available after a single Queueable job.
            Account accountUpdate = SharePointFolderService.resolveAccountFolderUpdate(accountId);
            Boolean originalBatchFlag = TriggerControlHelper.isBatchRunning;
            Database.SaveResult saveResult;
            try {
                TriggerControlHelper.isBatchRunning = true;
                saveResult = Database.update(accountUpdate, false);
            } finally {
                // This Queueable can be invoked by other automation. Do not
                // change its caller's trigger-control state.
                TriggerControlHelper.isBatchRunning = originalBatchFlag;
            }
            if (!saveResult.isSuccess()) {
                System.debug(
                    LoggingLevel.ERROR,
                    'Unable to save SharePoint folder IDs for Account ' + accountId + ': ' +
                    saveResult.getErrors()[0].getMessage()
                );
            }
        } catch (Exception exceptionRecord) {
            System.debug(
                LoggingLevel.ERROR,
                'SharePoint folder creation failed for Account ' + accountId + ': ' +
                exceptionRecord.getMessage()
            );
        }

        if (!pendingAccountIds.isEmpty()) {
            System.enqueueJob(new SharePointFolderCreationJob(
                new Set<Id>(pendingAccountIds),
                deferredUploads,
                deferredUploadAttempts
            ));
        } else if (deferredUploads != null && !deferredUploads.isEmpty()) {
            System.enqueueJob(new SharePointUploadJob(deferredUploads, deferredUploadAttempts));
        }
    }
}
