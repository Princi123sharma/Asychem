@isTest
private class OpenOpportunitiesCounterTest {
    @isTest
    static void testFetchOpportunityCounts() {
        // Setup test data
        Account testAccount = new Account(Name = 'Test Account',Nick_Name__c = 'Test Account');
        insert testAccount;
        Account_Catalog__c testAccountCatalog = new Account_Catalog__c(Account__c = testAccount.Id);
        insert testAccountCatalog;

        Opportunity testOpenOpp = new Opportunity(
            Name = 'Test Open Opportunity',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            closeDate = Date.today().addMonths(1)
        );
        insert testOpenOpp;

        Opportunity testClosedWonOpp = new Opportunity(
            Name = 'Test Closed Won Opportunity',
            AccountId = testAccount.Id,
            StageName = 'Closed Won',
            estimated_project_deadline__c = Date.today().addMonths(1),
            closeDate = Date.today().addMonths(1)
        );
        insert testClosedWonOpp;

        Opportunity testClosedLostOpp = new Opportunity(
            Name = 'Test Closed Lost Opportunity',
            AccountId = testAccount.Id,
            StageName = 'Closed Lost',
            estimated_project_deadline__c = Date.today().addMonths(2),
            closeDate = Date.today().addMonths(1)
        );
        insert testClosedLostOpp;

        // Invoke method under test
        OpenOpportunitiesCounter.OpportunityCounts result = OpenOpportunitiesCounter.fetchOpportunityCounts(testAccountCatalog.Id);

        // Verify results
        System.assertEquals(1, result.openOppsCount, 'Unexpected openOppsCount');
        System.assertEquals(2, result.closedOppsCount, 'Unexpected closedOppsCount');
    }

}