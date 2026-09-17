@IsTest
private class AccountSharePointTriggerHandlerTest {
    @IsTest
    static void identifiesAccountsWithAnyMissingSharePointFolder() {
        Account completeAccount = new Account(
            SharePoint_Folder_Id__c = 'account-folder',
            SharePoint_Contract_Folder_Id__c = 'contracts-folder',
            SharePoint_Opportunities_Folder_Id__c = 'opportunities-folder'
        );
        Account missingChildFolder = new Account(
            SharePoint_Folder_Id__c = 'account-folder',
            SharePoint_Contract_Folder_Id__c = null,
            SharePoint_Opportunities_Folder_Id__c = 'opportunities-folder'
        );

        System.assertEquals(false, AccountSharePointTriggerHandler.needsSharePointFolders(completeAccount));
        System.assertEquals(true, AccountSharePointTriggerHandler.needsSharePointFolders(missingChildFolder));
    }

    @IsTest
    static void reconciliationQueryFindsOnlyAccountsNeedingRepair() {
        Account completeAccount = new Account(
            Name = 'Complete Account',
            SharePoint_Folder_Id__c = 'account-folder',
            SharePoint_Contract_Folder_Id__c = 'contracts-folder',
            SharePoint_Opportunities_Folder_Id__c = 'opportunities-folder'
        );
        Account incompleteAccount = new Account(Name = 'Incomplete Account');
        TriggerControlHelper.isBatchRunning = true;
        try {
            insert new List<Account>{ completeAccount, incompleteAccount };
        } finally {
            TriggerControlHelper.isBatchRunning = false;
        }

        List<Account> candidates = [
            SELECT Id
            FROM Account
            WHERE SharePoint_Folder_Id__c = NULL
               OR SharePoint_Contract_Folder_Id__c = NULL
               OR SharePoint_Opportunities_Folder_Id__c = NULL
        ];

        System.assertEquals(1, candidates.size());
        System.assertEquals(incompleteAccount.Id, candidates[0].Id);
    }
}
