public with sharing class SharePointFolderCreationJob
    implements Queueable, Database.AllowsCallouts {

    private Set<Id> accountIds;

    public SharePointFolderCreationJob(Set<Id> accountIds) {
        this.accountIds = accountIds == null ? new Set<Id>() : accountIds;
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
            TriggerControlHelper.isBatchRunning = true;
            Database.SaveResult saveResult = Database.update(accountUpdate, false);
            TriggerControlHelper.isBatchRunning = false;
            if (!saveResult.isSuccess()) {
                System.debug(
                    LoggingLevel.ERROR,
                    'Unable to save SharePoint folder IDs for Account ' + accountId + ': ' +
                    saveResult.getErrors()[0].getMessage()
                );
            }
        } catch (Exception exceptionRecord) {
            TriggerControlHelper.isBatchRunning = false;
            System.debug(
                LoggingLevel.ERROR,
                'SharePoint folder creation failed for Account ' + accountId + ': ' +
                exceptionRecord.getMessage()
            );
        }

        if (!pendingAccountIds.isEmpty()) {
            System.enqueueJob(new SharePointFolderCreationJob(new Set<Id>(pendingAccountIds)));
        }
    }
}
