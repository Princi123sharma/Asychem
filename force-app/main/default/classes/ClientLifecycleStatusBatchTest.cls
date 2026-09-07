@IsTest
private class ClientLifecycleStatusBatchTest {
    @IsTest
    static void evaluatesPendingQuotedRfpOnlyAndPendingLandedPo() {
        Account quotedOnlyAccount = createAccount('Quoted Only Client');
        Opportunity quotedOnlyOpportunity = createOpportunity(
            quotedOnlyAccount.Id,
            'Quoted Only Opportunity',
            'Proposal Sent',
            Date.today().addMonths(-13),
            Date.today().addMonths(-13)
        );
        insert new Quote(
            Name = 'Quoted Only Quote',
            OpportunityId = quotedOnlyOpportunity.Id,
            Status = 'Sent to Client',
            Quote_due_to_Client__c = Date.today().addMonths(-13)
        );

        Account activeAccount = createAccount('Active Client');
        Opportunity activeOpportunity = createOpportunity(
            activeAccount.Id,
            'Recent RFP Opportunity',
            'Proposal Sent',
            Date.today().addDays(30),
            Date.today().addDays(-10)
        );
        insert new Quote(
            Name = 'Recent Quote',
            OpportunityId = activeOpportunity.Id,
            Status = 'Sent to Client',
            Quote_due_to_Client__c = Date.today().addDays(-10)
        );

        Account unsentQuoteAccount = createAccount('Unsent Quote Client');
        Opportunity unsentQuoteOpportunity = createOpportunity(
            unsentQuoteAccount.Id,
            'Unsent Quote Opportunity',
            'Inquiry Received',
            Date.today().addMonths(-13),
            Date.today().addMonths(-13)
        );
        insert new Quote(
            Name = 'Unsent Quote',
            OpportunityId = unsentQuoteOpportunity.Id,
            Status = 'Sent to China',
            Quote_due_to_Client__c = Date.today().addMonths(-13)
        );

        Account departedBdAccount = createAccount('Departed BD Client With Active Owner');
        departedBdAccount.BD_Departure_Date__c = Date.today().addMonths(-2);
        update departedBdAccount;

        Account deferredQuoteAccount = createAccount('Deferred Quote Client');
        Opportunity deferredQuoteOpportunity = createOpportunity(
            deferredQuoteAccount.Id,
            'Deferred Quote Opportunity',
            'Proposal Sent',
            Date.today().addDays(30),
            Date.today().addDays(-10)
        );
        insert new Quote(
            Name = 'Deferred Quote',
            OpportunityId = deferredQuoteOpportunity.Id,
            Status = 'Deferred',
            Quote_due_to_Client__c = Date.today().addDays(-10)
        );

        Account olderDeferredQuoteAccount = createAccount('Older Deferred Quote Client');
        Opportunity olderDeferredQuoteOpportunity = createOpportunity(
            olderDeferredQuoteAccount.Id,
            'Older Deferred Quote Opportunity',
            'Proposal Sent',
            Date.today().addDays(30),
            Date.today().addMonths(-2)
        );
        insert new Quote(
            Name = 'Older Deferred Quote',
            OpportunityId = olderDeferredQuoteOpportunity.Id,
            Status = 'Deferred',
            Quote_due_to_Client__c = Date.today().addMonths(-2)
        );
        insert new Quote(
            Name = 'Newer Sent to Client Quote',
            OpportunityId = olderDeferredQuoteOpportunity.Id,
            Status = 'Sent to Client',
            Quote_due_to_Client__c = Date.today().addDays(-5)
        );

        Account closedCompletedQuoteWithPoAccount = createAccount('Closed Completed Quote With PO Client');
        Opportunity closedCompletedQuoteWithPo = createOpportunity(
            closedCompletedQuoteWithPoAccount.Id,
            'Closed Completed Quote With PO',
            'Closed Completed',
            Date.today().addMonths(-13),
            Date.today().addMonths(-13)
        );
        closedCompletedQuoteWithPo.Client_PO__c = 'PO-CLOSED-COMPLETED-001';
        update closedCompletedQuoteWithPo;
        insert new Quote(
            Name = 'Old Quote With Closed Completed PO',
            OpportunityId = closedCompletedQuoteWithPo.Id,
            Status = 'Sent to China',
            Quote_due_to_Client__c = Date.today().addMonths(-13)
        );

        Account quoteWithSameOpportunityPoAccount = createAccount('Quote With Same Opportunity PO Client');
        Opportunity quoteWithSameOpportunityPo = createOpportunity(
            quoteWithSameOpportunityPoAccount.Id,
            'Quote With Same Opportunity PO',
            'Closed Won',
            Date.today().addMonths(-13),
            Date.today().addMonths(-13)
        );
        quoteWithSameOpportunityPo.Client_PO__c = 'PO-SAME-001';
        update quoteWithSameOpportunityPo;
        insert new Quote(
            Name = 'Old Sent Quote With Same Opportunity PO',
            OpportunityId = quoteWithSameOpportunityPo.Id,
            Status = 'Sent to Client',
            Quote_due_to_Client__c = Date.today().addMonths(-13)
        );

        Account quoteWithDifferentOpportunityPoAccount = createAccount('Quote With Different Opportunity PO Client');
        Opportunity quotedOpportunityWithoutPo = createOpportunity(
            quoteWithDifferentOpportunityPoAccount.Id,
            'Quoted Opportunity Without PO',
            'Proposal Sent',
            Date.today().addMonths(-13),
            Date.today().addMonths(-13)
        );
        insert new Quote(
            Name = 'Old Sent Quote Without Same Opportunity PO',
            OpportunityId = quotedOpportunityWithoutPo.Id,
            Status = 'Sent to Client',
            Quote_due_to_Client__c = Date.today().addMonths(-13)
        );
        Opportunity unrelatedPoOpportunity = createOpportunity(
            quoteWithDifferentOpportunityPoAccount.Id,
            'Unrelated PO Opportunity',
            'Closed Won',
            Date.today(),
            null
        );
        unrelatedPoOpportunity.Client_PO__c = 'PO-DIFFERENT-001';
        update unrelatedPoOpportunity;

        Account rfpWithoutQuoteAccount = createAccount('RFP Without Quote Client');
        createOpportunity(
            rfpWithoutQuoteAccount.Id,
            'Old RFP Without Quote Opportunity',
            'Proposal Sent',
            Date.today().addMonths(-13),
            Date.today().addMonths(-13)
        );

        Account rfpWithoutQuoteWithPoAccount = createAccount('RFP Without Quote With PO Client');
        Opportunity rfpWithoutQuoteWithPo = createOpportunity(
            rfpWithoutQuoteWithPoAccount.Id,
            'Old RFP Without Quote With PO Opportunity',
            'Closed Won',
            Date.today().addMonths(-13),
            Date.today().addMonths(-13)
        );
        rfpWithoutQuoteWithPo.Client_PO__c = 'PO-RFP-NO-QUOTE-001';
        update rfpWithoutQuoteWithPo;

        Account newRfpWithSameOpportunityPoAccount = createAccount('New RFP With Same Opportunity PO Client');
        Opportunity previousPoForSameOpportunityAccount = createOpportunity(
            newRfpWithSameOpportunityPoAccount.Id,
            'Previous PO For Same Opportunity Account',
            'Closed Won',
            Date.today().addMonths(-24),
            null
        );
        previousPoForSameOpportunityAccount.Client_PO__c = 'PO-PREV-SAME-001';
        update previousPoForSameOpportunityAccount;
        Opportunity newRfpWithSameOpportunityPo = createOpportunity(
            newRfpWithSameOpportunityPoAccount.Id,
            'New RFP With Same Opportunity PO',
            'Closed Won',
            Date.today().addMonths(-1),
            Date.today().addMonths(-19)
        );
        newRfpWithSameOpportunityPo.Client_PO__c = 'PO-NEW-SAME-001';
        update newRfpWithSameOpportunityPo;

        Account newRfpWithDifferentOpportunityPoAccount = createAccount('New RFP With Different Opportunity PO Client');
        Opportunity previousPoForDifferentOpportunityAccount = createOpportunity(
            newRfpWithDifferentOpportunityPoAccount.Id,
            'Previous PO For Different Opportunity Account',
            'Closed Won',
            Date.today().addMonths(-24),
            null
        );
        previousPoForDifferentOpportunityAccount.Client_PO__c = 'PO-PREV-DIFFERENT-001';
        update previousPoForDifferentOpportunityAccount;
        createOpportunity(
            newRfpWithDifferentOpportunityPoAccount.Id,
            'New RFP Without Same Opportunity PO',
            'Proposal Sent',
            Date.today().addMonths(-19),
            Date.today().addMonths(-19)
        );
        Opportunity unrelatedRecentPoOpportunity = createOpportunity(
            newRfpWithDifferentOpportunityPoAccount.Id,
            'Unrelated Recent PO Opportunity',
            'Closed Won',
            Date.today().addMonths(-1),
            null
        );
        unrelatedRecentPoOpportunity.Client_PO__c = 'PO-RECENT-DIFFERENT-001';
        update unrelatedRecentPoOpportunity;

        Account recentQuoteAfterOldPoNoRfpAccount = createAccount('Recent Quote After Old PO No RFP Client');
        Opportunity previousPoForRecentQuoteAccount = createOpportunity(
            recentQuoteAfterOldPoNoRfpAccount.Id,
            'Previous PO Before Recent Quote',
            'Closed Won',
            Date.today().addMonths(-24),
            null
        );
        previousPoForRecentQuoteAccount.Client_PO__c = 'PO-OLD-BEFORE-QUOTE-001';
        update previousPoForRecentQuoteAccount;
        Opportunity recentQuoteWithoutRfpOpportunity = createOpportunity(
            recentQuoteAfterOldPoNoRfpAccount.Id,
            'Recent Quote Without New RFP Date',
            'Proposal Sent',
            Date.today().addMonths(1),
            null
        );
        insert new Quote(
            Name = 'Recent Quote Without New RFP Date',
            OpportunityId = recentQuoteWithoutRfpOpportunity.Id,
            Status = 'Sent to Client',
            Quote_due_to_Client__c = Date.today().addMonths(-1)
        );

        Account newPendingCycleAccount = createAccount('New Pending Cycle Client');
        newPendingCycleAccount.Pending_Reason__c = 'Old approved reason';
        newPendingCycleAccount.Pending_Reason_Status__c = 'Approved';
        newPendingCycleAccount.Pending_Reason_Submitted_By__c = UserInfo.getUserId();
        newPendingCycleAccount.Pending_Reason_Submitted_Date__c = DateTime.now().addDays(-10);
        newPendingCycleAccount.Pending_Reason_Approver__c = UserInfo.getUserId();
        newPendingCycleAccount.Pending_Reason_Decision_Date__c = Date.today().addDays(-5);
        update newPendingCycleAccount;
        Opportunity newPendingCycleOpportunity = createOpportunity(
            newPendingCycleAccount.Id,
            'New Pending Cycle Opportunity',
            'Proposal Sent',
            Date.today().addMonths(-13),
            Date.today().addMonths(-13)
        );
        insert new Quote(
            Name = 'New Pending Cycle Quote',
            OpportunityId = newPendingCycleOpportunity.Id,
            Status = 'Sent to Client',
            Quote_due_to_Client__c = Date.today().addMonths(-13)
        );

        Account expiredNoActionAccount = createAccount('Expired No Action Client');
        expiredNoActionAccount.Client_Status__c = 'Pending';
        expiredNoActionAccount.Pending_Reason_Status__c = 'No Action';
        expiredNoActionAccount.Pending_Start_Date__c = Date.today().addMonths(-2);
        expiredNoActionAccount.Pending_Response_Due_Date__c = Date.today().addDays(-1);
        update expiredNoActionAccount;
        Opportunity expiredNoActionOpportunity = createOpportunity(
            expiredNoActionAccount.Id,
            'Expired No Action Opportunity',
            'Proposal Sent',
            Date.today().addMonths(-13),
            Date.today().addMonths(-13)
        );
        insert new Quote(
            Name = 'Expired No Action Quote',
            OpportunityId = expiredNoActionOpportunity.Id,
            Status = 'Sent to Client',
            Quote_due_to_Client__c = Date.today().addMonths(-13)
        );

        Test.startTest();
        Database.executeBatch(new ClientLifecycleStatusBatch(), 200);
        Test.stopTest();

        Map<Id, Account> accountsById = new Map<Id, Account>([
            SELECT
                Id,
                Client_Status__c,
                Pending_Reason__c,
                Pending_Reason_Status__c,
                Pending_Reason_Submitted_By__c,
                Pending_Reason_Submitted_Date__c,
                Pending_Reason_Approver__c,
                Pending_Reason_Decision_Date__c,
                Pending_Start_Date__c,
                Pending_Response_Due_Date__c
            FROM Account
            WHERE Id IN :new Set<Id>{
                quotedOnlyAccount.Id,
                activeAccount.Id,
                unsentQuoteAccount.Id,
                departedBdAccount.Id,
                deferredQuoteAccount.Id,
                olderDeferredQuoteAccount.Id,
                closedCompletedQuoteWithPoAccount.Id,
                quoteWithSameOpportunityPoAccount.Id,
                quoteWithDifferentOpportunityPoAccount.Id,
                rfpWithoutQuoteAccount.Id,
                rfpWithoutQuoteWithPoAccount.Id,
                newRfpWithSameOpportunityPoAccount.Id,
                newRfpWithDifferentOpportunityPoAccount.Id,
                recentQuoteAfterOldPoNoRfpAccount.Id,
                newPendingCycleAccount.Id,
                expiredNoActionAccount.Id
            }
        ]);

        System.assertEquals('Pending', accountsById.get(quotedOnlyAccount.Id).Client_Status__c);
        System.assertEquals('Active', accountsById.get(activeAccount.Id).Client_Status__c);
        System.assertEquals('Pending', accountsById.get(unsentQuoteAccount.Id).Client_Status__c);
        System.assertEquals('Active', accountsById.get(departedBdAccount.Id).Client_Status__c);
        System.assertEquals('Active', accountsById.get(deferredQuoteAccount.Id).Client_Status__c);
        System.assertEquals('Active', accountsById.get(olderDeferredQuoteAccount.Id).Client_Status__c);
        System.assertEquals('Active', accountsById.get(closedCompletedQuoteWithPoAccount.Id).Client_Status__c);
        System.assertEquals('Active', accountsById.get(quoteWithSameOpportunityPoAccount.Id).Client_Status__c);
        System.assertEquals('Pending', accountsById.get(quoteWithDifferentOpportunityPoAccount.Id).Client_Status__c);
        System.assertEquals('Pending', accountsById.get(rfpWithoutQuoteAccount.Id).Client_Status__c);
        System.assertEquals('Active', accountsById.get(rfpWithoutQuoteWithPoAccount.Id).Client_Status__c);
        System.assertEquals('Active', accountsById.get(newRfpWithSameOpportunityPoAccount.Id).Client_Status__c);
        System.assertEquals('Pending', accountsById.get(newRfpWithDifferentOpportunityPoAccount.Id).Client_Status__c);
        System.assertEquals('Pending', accountsById.get(recentQuoteAfterOldPoNoRfpAccount.Id).Client_Status__c);
        System.assertEquals('Pending', accountsById.get(newPendingCycleAccount.Id).Client_Status__c);
        System.assertEquals('No Action', accountsById.get(newPendingCycleAccount.Id).Pending_Reason_Status__c);
        System.assertEquals(Date.today(), accountsById.get(newPendingCycleAccount.Id).Pending_Start_Date__c);
        System.assertEquals(Date.today().addMonths(1), accountsById.get(newPendingCycleAccount.Id).Pending_Response_Due_Date__c);
        System.assertEquals(null, accountsById.get(newPendingCycleAccount.Id).Pending_Reason__c);
        System.assertEquals(null, accountsById.get(newPendingCycleAccount.Id).Pending_Reason_Submitted_By__c);
        System.assertEquals(null, accountsById.get(newPendingCycleAccount.Id).Pending_Reason_Submitted_Date__c);
        System.assertEquals(null, accountsById.get(newPendingCycleAccount.Id).Pending_Reason_Approver__c);
        System.assertEquals(null, accountsById.get(newPendingCycleAccount.Id).Pending_Reason_Decision_Date__c);
        System.assertEquals('Inactive', accountsById.get(expiredNoActionAccount.Id).Client_Status__c);
        System.assertEquals('No Action', accountsById.get(expiredNoActionAccount.Id).Pending_Reason_Status__c);

        Account landedPoAccount = createAccount('Landed PO Client');
        Map<Id, Date> oldPoDates = new Map<Id, Date>{
            landedPoAccount.Id => Date.today().addMonths(-19)
        };
        System.assertEquals(
            'Pending',
            ClientLifecycleStatusBatch.evaluateStatus(
                landedPoAccount.Id,
                new Map<Id, Date>{ landedPoAccount.Id => Date.today() },
                new Map<Id, Date>(),
                new Set<Id>(),
                new Set<Id>(),
                new Map<Id, Date>(),
                new Set<Id>(),
                oldPoDates,
                new Map<Id, Date>(),
                new Set<Id>(),
                new Set<Id>(),
                Date.today().addMonths(-6),
                Date.today().addMonths(-12),
                Date.today().addMonths(-18)
            )
        );

        Account postPoOldRfpAccount = createAccount('Post PO Old RFP Client');
        System.assertEquals(
            'Pending',
            ClientLifecycleStatusBatch.evaluateStatus(
                postPoOldRfpAccount.Id,
                new Map<Id, Date>{ postPoOldRfpAccount.Id => Date.today() },
                new Map<Id, Date>{ postPoOldRfpAccount.Id => Date.today().addMonths(-19) },
                new Set<Id>(),
                new Set<Id>(),
                new Map<Id, Date>(),
                new Set<Id>(),
                new Map<Id, Date>{ postPoOldRfpAccount.Id => Date.today().addMonths(-24) },
                new Map<Id, Date>(),
                new Set<Id>(),
                new Set<Id>(),
                Date.today().addMonths(-6),
                Date.today().addMonths(-12),
                Date.today().addMonths(-18)
            )
        );

        Account postPoRecentRfpAccount = createAccount('Post PO Recent RFP Client');
        System.assertEquals(
            'Active',
            ClientLifecycleStatusBatch.evaluateStatus(
                postPoRecentRfpAccount.Id,
                new Map<Id, Date>{ postPoRecentRfpAccount.Id => Date.today() },
                new Map<Id, Date>{ postPoRecentRfpAccount.Id => Date.today().addMonths(-6) },
                new Set<Id>(),
                new Set<Id>(),
                new Map<Id, Date>(),
                new Set<Id>(),
                new Map<Id, Date>{ postPoRecentRfpAccount.Id => Date.today().addMonths(-24) },
                new Map<Id, Date>(),
                new Set<Id>(),
                new Set<Id>(),
                Date.today().addMonths(-6),
                Date.today().addMonths(-12),
                Date.today().addMonths(-18)
            )
        );

        Account postPoRecentQuoteNoRfpAccount = createAccount('Post PO Recent Quote No RFP Client');
        System.assertEquals(
            'Pending',
            ClientLifecycleStatusBatch.evaluateStatus(
                postPoRecentQuoteNoRfpAccount.Id,
                new Map<Id, Date>{ postPoRecentQuoteNoRfpAccount.Id => Date.today() },
                new Map<Id, Date>(),
                new Set<Id>(),
                new Set<Id>(),
                new Map<Id, Date>{ postPoRecentQuoteNoRfpAccount.Id => Date.today().addMonths(-1) },
                new Set<Id>(),
                new Map<Id, Date>{ postPoRecentQuoteNoRfpAccount.Id => Date.today().addMonths(-24) },
                new Map<Id, Date>(),
                new Set<Id>(),
                new Set<Id>(),
                Date.today().addMonths(-6),
                Date.today().addMonths(-12),
                Date.today().addMonths(-18)
            )
        );

        Account inactiveOwnerAccount = createAccount('Inactive Owner Client');
        System.assertEquals(
            'Inactive',
            ClientLifecycleStatusBatch.evaluateStatus(
                inactiveOwnerAccount.Id,
                new Map<Id, Date>{ inactiveOwnerAccount.Id => Date.today() },
                new Map<Id, Date>(),
                new Set<Id>(),
                new Set<Id>(),
                new Map<Id, Date>(),
                new Set<Id>(),
                new Map<Id, Date>(),
                new Map<Id, Date>(),
                new Set<Id>(),
                new Set<Id>{ inactiveOwnerAccount.Id },
                Date.today().addMonths(-6),
                Date.today().addMonths(-12),
                Date.today().addMonths(-18)
            )
        );

        Account oldNoRfpAccount = createAccount('Old No RFP Client');
        System.assertEquals(
            'Inactive',
            ClientLifecycleStatusBatch.evaluateStatus(
                oldNoRfpAccount.Id,
                new Map<Id, Date>{ oldNoRfpAccount.Id => Date.today().addMonths(-7) },
                new Map<Id, Date>(),
                new Set<Id>(),
                new Set<Id>(),
                new Map<Id, Date>(),
                new Set<Id>(),
                new Map<Id, Date>(),
                new Map<Id, Date>(),
                new Set<Id>(),
                new Set<Id>(),
                Date.today().addMonths(-6),
                Date.today().addMonths(-12),
                Date.today().addMonths(-18)
            )
        );

        Account oldWithRfpAccount = createAccount('Old With RFP Client');
        System.assertEquals(
            'Active',
            ClientLifecycleStatusBatch.evaluateStatus(
                oldWithRfpAccount.Id,
                new Map<Id, Date>{ oldWithRfpAccount.Id => Date.today().addMonths(-7) },
                new Map<Id, Date>{ oldWithRfpAccount.Id => Date.today().addDays(-10) },
                new Set<Id>(),
                new Set<Id>(),
                new Map<Id, Date>(),
                new Set<Id>(),
                new Map<Id, Date>(),
                new Map<Id, Date>(),
                new Set<Id>(),
                new Set<Id>(),
                Date.today().addMonths(-6),
                Date.today().addMonths(-12),
                Date.today().addMonths(-18)
            )
        );

        Account recentNoRfpAccount = createAccount('Recent No RFP Client');
        System.assertEquals(
            'Active',
            ClientLifecycleStatusBatch.evaluateStatus(
                recentNoRfpAccount.Id,
                new Map<Id, Date>{ recentNoRfpAccount.Id => Date.today().addMonths(-5) },
                new Map<Id, Date>(),
                new Set<Id>(),
                new Set<Id>(),
                new Map<Id, Date>(),
                new Set<Id>(),
                new Map<Id, Date>(),
                new Map<Id, Date>(),
                new Set<Id>(),
                new Set<Id>(),
                Date.today().addMonths(-6),
                Date.today().addMonths(-12),
                Date.today().addMonths(-18)
            )
        );
    }

    @IsTest
    static void canBeScheduled() {
        Test.startTest();
        String jobId = ClientLifecycleStatusBatch.scheduleMonthly();
        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }

    private static Account createAccount(String accountName) {
        Account accountRecord = new Account(
            Name = accountName,
            Nick_Name__c = accountName.left(20),
            Client_Status__c = 'Active'
        );
        insert accountRecord;
        return accountRecord;
    }

    private static Opportunity createOpportunity(
        Id accountId,
        String opportunityName,
        String stageName,
        Date closeDate,
        Date rfpDate
    ) {
        Opportunity opportunityRecord = new Opportunity(
            Name = opportunityName,
            AccountId = accountId,
            StageName = stageName,
            CloseDate = closeDate,
            LeadSource = 'Existing Client',
            Date_RFP_due_to_Client__c = rfpDate
        );
        insert opportunityRecord;
        return opportunityRecord;
    }
}