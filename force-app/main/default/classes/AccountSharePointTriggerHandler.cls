public with sharing class AccountSharePointTriggerHandler {
    private static Set<Id> queuedAccountIds = new Set<Id>();

    public static void handleAfterInsertOrUpdate(List<Account> accountRecords) {
        if (TriggerControlHelper.isBatchRunning || accountRecords == null) return;

        Set<Id> accountIdsToQueue = new Set<Id>();
        for (Account accountRecord : accountRecords) {
            if (accountRecord.Id == null || queuedAccountIds.contains(accountRecord.Id)) continue;
            if (needsSharePointFolders(accountRecord)) {
                accountIdsToQueue.add(accountRecord.Id);
            }
        }

        if (!accountIdsToQueue.isEmpty()) {
            queuedAccountIds.addAll(accountIdsToQueue);
            System.enqueueJob(new SharePointFolderCreationJob(accountIdsToQueue));
        }
    }

    @TestVisible
    private static Boolean needsSharePointFolders(Account accountRecord) {
        return String.isBlank(accountRecord.SharePoint_Folder_Id__c)
            || String.isBlank(accountRecord.SharePoint_Contract_Folder_Id__c)
            || String.isBlank(accountRecord.SharePoint_Opportunities_Folder_Id__c);
    }
}
