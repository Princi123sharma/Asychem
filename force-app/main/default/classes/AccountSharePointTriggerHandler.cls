public with sharing class AccountSharePointTriggerHandler {
    private static Set<Id> queuedAccountIds = new Set<Id>();

    public static void handleAfterInsert(List<Account> accountRecords) {
        if (accountRecords == null) return;

        Set<Id> accountIdsToQueue = new Set<Id>();
        for (Account accountRecord : accountRecords) {
            if (accountRecord.Id == null || queuedAccountIds.contains(accountRecord.Id)) continue;
            if (needsSharePointFolders(accountRecord)) {
                accountIdsToQueue.add(accountRecord.Id);
            }
        }

        // Method sync jobs already use their Queueable allowance. Defer folder
        // provisioning through a platform event so Accounts created by that
        // sync are provisioned after its transaction commits.
        if (TriggerControlHelper.isBatchRunning && !accountIdsToQueue.isEmpty()) {
            publishDeferredProvisioningEvents(accountIdsToQueue);
        } else if (!accountIdsToQueue.isEmpty() && Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
            queuedAccountIds.addAll(accountIdsToQueue);
            System.enqueueJob(new SharePointFolderCreationJob(accountIdsToQueue));
        } else if (!accountIdsToQueue.isEmpty()) {
            publishDeferredProvisioningEvents(accountIdsToQueue);
        }
    }

    private static void publishDeferredProvisioningEvents(Set<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) return;
        List<SharePoint_Folder_Provisioning__e> deferredEvents = new List<SharePoint_Folder_Provisioning__e>();
        for (Id accountId : accountIds) {
            deferredEvents.add(new SharePoint_Folder_Provisioning__e(Account_Id__c = String.valueOf(accountId)));
        }
        EventBus.publish(deferredEvents);
    }

    @TestVisible
    private static Boolean needsSharePointFolders(Account accountRecord) {
        return String.isBlank(accountRecord.SharePoint_Folder_Id__c)
            || String.isBlank(accountRecord.SharePoint_Contract_Folder_Id__c)
            || String.isBlank(accountRecord.SharePoint_Opportunities_Folder_Id__c);
    }
}
