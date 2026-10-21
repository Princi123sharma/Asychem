@IsTest
private class SharePointFolderReconciliationBatchTest {
    @IsTest
    static void queuesFolderCreationForANonEmptyBatchScope() {
        Account incompleteAccount = SharePointTestDataFactory.insertAccount('Reconciliation Incomplete');
        Account completeAccount = SharePointTestDataFactory.insertAccount('Reconciliation Complete');
        completeAccount.SharePoint_Folder_Id__c = 'root-folder';
        completeAccount.SharePoint_Contract_Folder_Id__c = 'contracts-folder';
        completeAccount.SharePoint_Opportunities_Folder_Id__c = 'opportunities-folder';
        TriggerControlHelper.isBatchRunning = true;
        try {
            update completeAccount;
        } finally {
            TriggerControlHelper.isBatchRunning = false;
        }

        Integer jobsBefore = Limits.getQueueableJobs();
        new SharePointFolderReconciliationBatch().execute(
            null,
            new List<Account>{ incompleteAccount, completeAccount }
        );

        System.assertEquals(jobsBefore + 1, Limits.getQueueableJobs());
    }

    @IsTest
    static void doesNotQueueWorkForAnEmptyBatchScope() {
        Integer jobsBefore = Limits.getQueueableJobs();
        new SharePointFolderReconciliationBatch().execute(null, new List<Account>());
        System.assertEquals(jobsBefore, Limits.getQueueableJobs());
    }
}
