@IsTest
private class SharePointFolderCreationJobTest {
    @TestSetup
    static void setupAccounts() {
        Test.startTest();
        List<Account> accounts = new List<Account>();
        for (Integer index = 0; index < 7; index++) {
            accounts.add(new Account(Name = 'Batch Test ' + index, Nick_Name__c = 'Batch Test ' + index));
        }
        TriggerControlHelper.isBatchRunning = true;
        try { insert accounts; }
        finally { TriggerControlHelper.isBatchRunning = false; }
        Test.stopTest();
    }

    private class FolderMock implements HttpCalloutMock {
        private Boolean failFirst;
        FolderMock(Boolean failFirst) { this.failFirst = failFirst; }
        public HttpResponse respond(HttpRequest request) {
            System.assertEquals(0, Limits.getDmlStatements(), 'Every callout must precede Account updates.');
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            if (request.getEndpoint().contains('/$batch')) {
                Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(request.getBody());
                List<Object> replies = new List<Object>();
                for (Object value : (List<Object>) payload.get('requests')) {
                    Map<String, Object> child = (Map<String, Object>) value;
                    String url = (String) child.get('url');
                    String parent = url.substringAfter('/items/').substringBefore(':/');
                    String name = url.contains('Contracts') ? 'Contracts' : 'Opportunities';
                    replies.add(new Map<String, Object>{
                        'id' => child.get('id'),
                        'status' => failFirst && parent == 'parent-0' ? 503 : 200,
                        'body' => new Map<String, Object>{
                            'id' => parent + '-' + name, 'folder' => new Map<String, Object>()
                        }
                    });
                }
                response.setBody(JSON.serialize(new Map<String, Object>{ 'responses' => replies }));
            } else {
                List<Object> parents = new List<Object>();
                for (Integer index = 0; index < 7; index++) {
                    parents.add(new Map<String, Object>{
                        'id' => 'parent-' + index,
                        'name' => 'Batch Test ' + index + ' ' + Date.today().year()
                    });
                }
                response.setBody(JSON.serialize(new Map<String, Object>{ 'value' => parents }));
            }
            return response;
        }
    }

    private static Set<Id> configure(Integer count, Boolean failFirst) {
        SharePointFolderService.configOverride = new SharePoint_Config__mdt(
            Drive_Id__c = 'drive-id', Accounts_Parent_Item_Id__c = 'accounts-parent'
        );
        Test.setMock(HttpCalloutMock.class, new FolderMock(failFirst));
        return new Map<Id, Account>([SELECT Id FROM Account ORDER BY Name LIMIT :count]).keySet();
    }

    @IsTest
    static void savesFiveAccountsAfterAllCallouts() {
        Set<Id> ids = configure(5, false);
        Test.startTest();
        new SharePointFolderCreationJob(ids).execute(null);
        System.assertEquals(false, TriggerControlHelper.isBatchRunning);
        System.assertEquals(0, Limits.getQueueableJobs(), 'Exactly five Accounts need no continuation.');
        Test.stopTest();
        System.assertEquals(5, [SELECT COUNT() FROM Account WHERE SharePoint_Opportunities_Folder_Id__c != null]);
    }

    @IsTest
    static void continuesAfterOneAccountFails() {
        Set<Id> ids = configure(5, true);
        Test.startTest();
        TriggerControlHelper.isBatchRunning = true;
        new SharePointFolderCreationJob(ids).execute(null);
        System.assertEquals(true, TriggerControlHelper.isBatchRunning, 'Restore the caller flag.');
        TriggerControlHelper.isBatchRunning = false;
        Test.stopTest();
        System.assertEquals(4, [SELECT COUNT() FROM Account WHERE SharePoint_Opportunities_Folder_Id__c != null]);
        System.assertEquals(null, [SELECT SharePoint_Folder_Id__c FROM Account WHERE Name = 'Batch Test 0'].SharePoint_Folder_Id__c);
    }

    @IsTest
    static void queuesTheRemainderAfterFiveAccounts() {
        Set<Id> ids = configure(7, false);
        Test.startTest();
        new SharePointFolderCreationJob(ids).execute(null);
        System.assertEquals(5, [SELECT COUNT() FROM Account WHERE SharePoint_Opportunities_Folder_Id__c != null]);
        System.assertEquals(1, Limits.getQueueableJobs(), 'The remainder must use a single continuation.');
        Test.stopTest();
        System.assertEquals(7, [SELECT COUNT() FROM Account WHERE SharePoint_Opportunities_Folder_Id__c != null]);
    }
}