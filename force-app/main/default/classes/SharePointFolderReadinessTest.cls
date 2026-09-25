@IsTest
private class SharePointFolderReadinessTest {
    @IsTest
    static void returnsFalseWhenAnyFolderIdIsMissing() {
        Account accountRecord = SharePointTestDataFactory.insertAccount('Pending SharePoint Account');
        accountRecord.SharePoint_Folder_Id__c = 'parent';
        accountRecord.SharePoint_Contract_Folder_Id__c = 'contracts';
        TriggerControlHelper.isBatchRunning = true;
        try { update accountRecord; } finally { TriggerControlHelper.isBatchRunning = false; }

        Integer calloutsBefore = Limits.getCallouts();
        System.assertEquals(false, LinkEaseController.getFolderReadiness(accountRecord.Id).isReady);
        System.assertEquals(calloutsBefore, Limits.getCallouts(), 'Readiness uses saved Salesforce IDs only.');
    }

    @IsTest
    static void returnsTrueForAccountAndOpportunityWhenAllIdsExist() {
        Account accountRecord = SharePointTestDataFactory.insertAccount('Ready SharePoint Account');
        accountRecord.SharePoint_Folder_Id__c = 'parent';
        accountRecord.SharePoint_Contract_Folder_Id__c = 'contracts';
        accountRecord.SharePoint_Opportunities_Folder_Id__c = 'opportunities';
        TriggerControlHelper.isBatchRunning = true;
        try { update accountRecord; } finally { TriggerControlHelper.isBatchRunning = false; }
        Opportunity opportunityRecord = new Opportunity(Name = 'Readiness Opportunity', AccountId = accountRecord.Id, StageName = 'Prospecting', CloseDate = Date.today());
        insert opportunityRecord;

        System.assertEquals(true, LinkEaseController.getFolderReadiness(accountRecord.Id).isReady);
        System.assertEquals(true, LinkEaseController.getFolderReadiness(opportunityRecord.Id).isReady);
    }
}
