@isTest
private class ActiveOrInactiveAccountCheckerTest {

    @isTest
    static void testFetchCounts() {

        Id rtId = [SELECT Id FROM RecordType WHERE Name = 'Parent Account' ].Id;
        // Create test data
        Account testAccount = new Account(Name = 'Test Account', Nick_Name__c = 'Test', Open_Opportunities_Last_6_Months__c = 5, Active_Contracts__c = 3, RecordTypeId = rtId);
        insert testAccount;

        // Call the method to test
        ActiveOrInactiveAccountChecker.OpportunityCounts counts = ActiveOrInactiveAccountChecker.fetchCounts(testAccount.Id);

        // Verify the results
        System.assertEquals(5, counts.openOppsCount, 'Open Opportunities count should match');
        System.assertEquals(3, counts.activeContractsCount, 'Active Contracts count should match');
    }

    @isTest
    static void testGetOpportunitiesCount() {
        Id rtId = [SELECT Id FROM RecordType WHERE Name = 'Parent Account' ].Id;
        // Create test data
        Account testAccount = new Account(Name = 'Test Account', Nick_Name__c = 'Test', Open_Opportunities_Last_6_Months__c = 8, RecordTypeId = rtId);
        insert testAccount;

        // Call the method to test
        Integer opportunitiesCount1 = ActiveOrInactiveAccountChecker.getOpportunitiesCount(testAccount.Id);

        // Verify the result
        System.assertEquals(8, opportunitiesCount1, 'Opportunities count should match');
    }

    @isTest
    static void testGetActiveContracts() {
        Id rtId = [SELECT Id FROM RecordType WHERE Name = 'Parent Account' ].Id;
        // Create test data
        Account testAccount = new Account(Name = 'Test Account', Nick_Name__c = 'Test', Active_Contracts__c = 4, RecordTypeId = rtId);
        insert testAccount;

        // Call the method to test
        Integer activeContractsCount1 = ActiveOrInactiveAccountChecker.getActiveContracts(testAccount.Id);

        // Verify the result
        System.assertEquals(4, activeContractsCount1, 'Active Contracts count should match');
    }
}