@isTest
private class CheckActiveInactiveAccountBatchTest {

    @isTest
    static void testCheckActiveInactiveAccountBatch() {
        Id rtId = [SELECT Id FROM RecordType WHERE Name = 'Account' LIMIT 1].Id;

        // Create test data: Account, Opportunity, and Contract records
        Account testAccount = new Account(
            Name = 'Test Account', 
            Nick_Name__c = 'TestAcc',
            RecordTypeId = rtId
        );
        insert testAccount;

        Opportunity testOpportunity = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Closed Won',
            CloseDate = Date.newInstance(2023, 12, 31),
            AccountId = testAccount.Id,
            LeadSource = 'Existing Client'
        );
        insert testOpportunity;

        Contract testContract = new Contract(
            Type_of_Contract__c = '2-way CDA',
            Template_Type__c = 'Client',
            Name = 'Test Contract',
            Status = 'Client Review',
            AccountId = testAccount.Id
        );
        insert testContract;


        testContract.Status = 'Active';
        update testContract;

        Quote testQuote = new Quote(
            Name = 'Test Quote',
            opportunityId = testOpportunity.Id,
            Status = 'Approved'
        );
        insert testQuote;


        Account testAccount1 = new Account(
            Name = 'Test Account1', 
            Nick_Name__c = 'TestAcc1',
            RecordTypeId = rtId
        );
        insert testAccount1;

        Opportunity testOpportunity1 = new Opportunity(
            Name = 'Test Opportunity1',
            StageName = 'Closed Lost',
            CloseDate = Date.newInstance(2023, 12, 31),
            AccountId = testAccount1.Id,
            LeadSource = 'Existing Client'
        );
        insert testOpportunity1;

        Contract testContract1 = new Contract(
            Type_of_Contract__c = '2-way CDA',
            Template_Type__c = 'Client',
            Name = 'Test Contract1',
            Status = 'Client Review',
            AccountId = testAccount1.Id
        );
        insert testContract1;

        Quote testQuote1 = new Quote(
            Name = 'Test Quote1',
            opportunityId = testOpportunity1.Id,
            Status = 'New Quote'
        );
        insert testQuote1;

        Test.startTest();
        Database.executeBatch(new CheckActiveInactiveAccountBatch());
        Test.stopTest();
    }
}