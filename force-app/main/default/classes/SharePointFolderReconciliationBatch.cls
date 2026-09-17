public with sharing class SharePointFolderReconciliationBatch
    implements Database.Batchable<SObject> {

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id
            FROM Account
            WHERE SharePoint_Folder_Id__c = NULL
               OR SharePoint_Contract_Folder_Id__c = NULL
               OR SharePoint_Opportunities_Folder_Id__c = NULL
        ]);
    }

    public void execute(Database.BatchableContext context, List<Account> scope) {
        Set<Id> accountIds = new Map<Id, Account>(scope).keySet();
        if (!accountIds.isEmpty()) {
            System.enqueueJob(new SharePointFolderCreationJob(accountIds));
        }
    }

    public void finish(Database.BatchableContext context) {
        System.debug(LoggingLevel.INFO, 'SharePoint folder reconciliation completed.');
    }
}
