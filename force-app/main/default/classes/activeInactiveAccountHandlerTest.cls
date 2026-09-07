@isTest
private class activeInactiveAccountHandlerTest {
    @isTest
    static void testActiveInactiveAccountHandlert() {
        Id rtId = [SELECT Id FROM RecordType WHERE Name = 'Account' LIMIT 1].Id;

        // Create test data: Account, Opportunity, and Contract records
        Account testAccount = new Account(
            Name = 'Test Account', 
            Nick_Name__c = 'TestAcc',
            RecordTypeId = rtId,
            Active__c = true
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
            AccountId = testAccount.Id,
            StartDate = Date.newInstance(2024, 01, 15),
            ContractTerm = 5
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
        
        Account testAccount2 = new Account(
            Name = 'Test Account2', 
            Nick_Name__c = 'TestAcc2',
            RecordTypeId = rtId,
            Active__c = true
        );
        insert testAccount2;
        
        Opportunity testOpportunity2 = new Opportunity(
            Name = 'Test Opportunity2',
            StageName = 'Inquiry Received',
            CloseDate = Date.newInstance(2023, 12, 31),
            AccountId = testAccount2.Id,
            LeadSource = 'Existing Client'
        );
        insert testOpportunity2;
        
        Account testAccount3 = new Account(
            Name = 'Test Account3', 
            Nick_Name__c = 'TestAcc3',
            RecordTypeId = rtId,
            Active__c = true
        );
        insert testAccount3;
        Contact testContact = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            AccountId = testAccount.Id
        );
        insert testContact;
        Opportunity testOpportunity3 = new Opportunity(
            Name = 'Test Opportunity3',
            StageName = 'Proposal Sent',
            CloseDate = Date.newInstance(2023, 12, 31),
            AccountId = testAccount3.Id,
            LeadSource = 'Existing Client',
			Primary_Contact__c = testContact.Id             
        );
        insert testOpportunity3;

        Test.startTest();
        testOpportunity3.StageName = 'Proposal Revision';
        update testOpportunity3;
        activeInactiveAccountHandler.fetchReason(testAccount.Id);
        activeInactiveAccountHandler.fetchReason(testAccount2.Id);
        activeInactiveAccountHandler.fetchReason(testAccount3.Id);
        Test.stopTest();
    }

    @isTest
    static void fetchReasonSupportsAccountCatalogRecordId() {
        Id rtId = [SELECT Id FROM RecordType WHERE Name = 'Account' LIMIT 1].Id;

        Account testAccount = new Account(
            Name = 'Catalog Status Account',
            Nick_Name__c = 'CatalogStatus',
            RecordTypeId = rtId,
            Client_Status__c = 'Pending',
            Active__c = false
        );
        insert testAccount;

        Account_Catalog__c catalogRecord = new Account_Catalog__c(
            Account__c = testAccount.Id
        );
        insert catalogRecord;

        Test.startTest();
        activeInactiveAccountHandler.ActiveReason result = activeInactiveAccountHandler.fetchReason(catalogRecord.Id);
        Test.stopTest();

        System.assertEquals('Pending', result.status);
        System.assertEquals(false, result.isActive);
        System.assertEquals(true, result.reason.contains('Client is currently on the Pending Client List.'));
    }

    @isTest
    static void fetchReasonReturnsInactiveStatusReason() {
        Id rtId = [SELECT Id FROM RecordType WHERE Name = 'Account' LIMIT 1].Id;

        Account testAccount = new Account(
            Name = 'Inactive Status Account',
            Nick_Name__c = 'InactiveStatus',
            RecordTypeId = rtId,
            Client_Status__c = 'Inactive',
            Active__c = false
        );
        insert testAccount;

        Test.startTest();
        activeInactiveAccountHandler.ActiveReason result = activeInactiveAccountHandler.fetchReason(testAccount.Id);
        Test.stopTest();

        System.assertEquals('Inactive', result.status);
        System.assertEquals(false, result.isActive);
        System.assertEquals(true, result.reason.contains('Client is currently on the Inactive Client List.'));
    }

    @isTest
    static void evaluateFirstInactiveRuleHandlesNullAndRfpAccount() {
        Id rtId = [SELECT Id FROM RecordType WHERE Name = 'Account' LIMIT 1].Id;

        Account testAccount = new Account(
            Name = 'Inactive Rule RFP Account',
            Nick_Name__c = 'RuleRFP',
            RecordTypeId = rtId,
            Client_Status__c = 'Active',
            Active__c = true
        );
        insert testAccount;

        Opportunity testOpportunity = new Opportunity(
            Name = 'Inactive Rule RFP Opportunity',
            StageName = 'Inquiry Received',
            CloseDate = Date.today().addDays(30),
            AccountId = testAccount.Id,
            LeadSource = 'Existing Client',
            Date_RFP_due_to_Client__c = Date.today()
        );
        insert testOpportunity;

        Test.startTest();
        activeInactiveAccountHandler.InactiveRuleResult nullResult =
            activeInactiveAccountHandler.evaluateFirstInactiveRule(null);
        activeInactiveAccountHandler.InactiveRuleResult accountResult =
            activeInactiveAccountHandler.evaluateFirstInactiveRule(testAccount.Id);
        Test.stopTest();

        System.assertEquals(1, nullResult.errors.size());
        System.assertEquals(1, accountResult.accountsEvaluated);
        System.assertEquals(0, accountResult.accountsWithOldCda);
        System.assertEquals(1, accountResult.accountsWithRfp);
        System.assertEquals(0, accountResult.accountsUpdated);
        System.assertEquals(0, accountResult.errors.size());
    }
}