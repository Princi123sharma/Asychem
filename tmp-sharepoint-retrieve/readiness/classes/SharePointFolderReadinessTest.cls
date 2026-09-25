@IsTest
private class SharePointFolderReadinessTest {
    private class ReadinessMock implements HttpCalloutMock {
        private String opportunityId;
        private Integer opportunityStatus;
        ReadinessMock(String opportunityId, Integer opportunityStatus) {
            this.opportunityId = opportunityId;
            this.opportunityStatus = opportunityStatus;
        }
        public HttpResponse respond(HttpRequest request) {
            System.assert(request.getEndpoint().endsWith('/v1.0/$batch'));
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody(JSON.serialize(new Map<String, Object>{
                'responses' => new List<Object>{
                    new Map<String, Object>{ 'id' => '1', 'status' => opportunityStatus,
                        'body' => new Map<String, Object>{ 'id' => opportunityId, 'folder' => new Map<String, Object>() } },
                    new Map<String, Object>{ 'id' => '0', 'status' => 200,
                        'body' => new Map<String, Object>{ 'id' => 'contracts', 'folder' => new Map<String, Object>() } }
                }
            }));
            return response;
        }
    }

    @TestSetup
    static void setupRecords() {
        Test.startTest();
        Account completeAccount = insertAccount(true);
        insertAccount(false);
        insert new Opportunity(
            Name = 'Readiness Opportunity', AccountId = completeAccount.Id,
            StageName = 'Prospecting', CloseDate = Date.today()
        );
        Test.stopTest();
    }

    private static Account makeAccount(Boolean complete) {
        String expectedName = complete ? 'Ready Account' : 'Pending Account';
        LinkEaseController.configOverride = new SharePoint_Config__mdt(Drive_Id__c = 'drive-id');
        return [SELECT Id FROM Account WHERE Name = :expectedName LIMIT 1];
    }

    private static Account insertAccount(Boolean complete) {
        Account accountRecord = new Account(
            Name = complete ? 'Ready Account' : 'Pending Account', Nick_Name__c = complete ? 'Ready Account' : 'Pending Account', SharePoint_Folder_Id__c = complete ? 'parent' : 'pending-parent',
            SharePoint_Contract_Folder_Id__c = complete ? 'contracts' : 'pending-contracts',
            SharePoint_Opportunities_Folder_Id__c = complete ? 'opportunities' : null
        );
        TriggerControlHelper.isBatchRunning = true;
        try { insert accountRecord; }
        finally { TriggerControlHelper.isBatchRunning = false; }
        LinkEaseController.configOverride = new SharePoint_Config__mdt(Drive_Id__c = 'drive-id');
        return accountRecord;
    }

    @IsTest
    static void waitsForSavedIdsWithoutCallingGraph() {
        Account accountRecord = makeAccount(false);
        Integer beforeCalls = Limits.getCallouts();
        System.assertEquals(false, LinkEaseController.getFolderReadiness(accountRecord.Id).isReady);
        System.assertEquals(beforeCalls, Limits.getCallouts());
    }

    @IsTest
    static void requiresBothExistingChildrenToMatchSavedIds() {
        Account accountRecord = makeAccount(true);
        Test.setMock(HttpCalloutMock.class, new ReadinessMock('opportunities', 200));
        Test.startTest();
        System.assertEquals(true, LinkEaseController.getFolderReadiness(accountRecord.Id).isReady);
        Test.setMock(HttpCalloutMock.class, new ReadinessMock('replacement', 200));
        System.assertEquals(false, LinkEaseController.getFolderReadiness(accountRecord.Id).isReady);
        Test.setMock(HttpCalloutMock.class, new ReadinessMock(null, 404));
        System.assertEquals(false, LinkEaseController.getFolderReadiness(accountRecord.Id).isReady);
        Test.stopTest();
    }

    @IsTest
    static void checksTheParentAccountForOpportunityPages() {
        Account accountRecord = makeAccount(true);
        Opportunity opportunityRecord = [SELECT Id FROM Opportunity WHERE AccountId = :accountRecord.Id LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new ReadinessMock('opportunities', 200));
        Test.startTest();
        System.assertEquals(true, LinkEaseController.getFolderReadiness(opportunityRecord.Id).isReady);
        Test.stopTest();
    }
}