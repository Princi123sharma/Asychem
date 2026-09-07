@IsTest(SeeAllData=false)
private class OpportunityContractCountBatchTest {
    @testSetup
    static void setupTestData() {
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
            StageName = 'Proposal Sent',
            CloseDate = Date.newInstance(2023, 12, 31),
            AccountId = testAccount.Id,
            LeadSource = 'Existing Client'
        );
        insert testOpportunity;

        Contract testContract = new Contract(
            Type_of_Contract__c = '2-way CDA',
            Template_Type__c = 'Client',
            Name = 'Test',
            Status = 'Client Review',
            AccountId = testAccount.Id
        );
        insert testContract;
    }

    @IsTest
    static void testOpportunityContractCountBatch() {
        Test.startTest();

        // Execute the batch class
        OpportunityContractCountBatch batchClassInstance = new OpportunityContractCountBatch();
        Database.executeBatch(batchClassInstance);

        Test.stopTest();
    }
}