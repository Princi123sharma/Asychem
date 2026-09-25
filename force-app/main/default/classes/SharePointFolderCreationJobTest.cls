@IsTest
private class SharePointFolderCreationJobTest {
    private class FolderMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            if (request.getMethod() == 'GET') {
                // Each lookup intentionally returns no existing folder, so
                // the job must create the Account, Contracts and Opportunities folders.
                response.setBody('{"value":[]}');
            } else {
                response.setStatusCode(201);
                response.setBody('{"id":"' + request.getEndpoint().substringAfter('/items/').substringBefore('/children') + '-created","folder":{}}');
            }
            return response;
        }
    }

    @IsTest
    static void createsAllFoldersForOneAccountAndRestoresCallerFlag() {
        Account accountRecord = SharePointTestDataFactory.insertAccount('Folder Job Account');
        SharePointFolderService.configOverride = new SharePoint_Config__mdt(
            Drive_Id__c = 'drive-id', Accounts_Parent_Item_Id__c = 'accounts-parent'
        );
        Test.setMock(HttpCalloutMock.class, new FolderMock());

        Test.startTest();
        TriggerControlHelper.isBatchRunning = true;
        new SharePointFolderCreationJob(new Set<Id>{ accountRecord.Id }).execute(null);
        System.assertEquals(true, TriggerControlHelper.isBatchRunning);
        TriggerControlHelper.isBatchRunning = false;
        Test.stopTest();

        Account saved = [
            SELECT SharePoint_Folder_Id__c, SharePoint_Contract_Folder_Id__c,
                   SharePoint_Opportunities_Folder_Id__c
            FROM Account WHERE Id = :accountRecord.Id
        ];
        System.assertNotEquals(null, saved.SharePoint_Folder_Id__c);
        System.assertNotEquals(null, saved.SharePoint_Contract_Folder_Id__c);
        System.assertNotEquals(null, saved.SharePoint_Opportunities_Folder_Id__c);
    }

    @IsTest
    static void queuesRemainingAccountsOneAtATime() {
        Account first = SharePointTestDataFactory.insertAccount('Folder Job First');
        Account second = SharePointTestDataFactory.insertAccount('Folder Job Second');
        SharePointFolderService.configOverride = new SharePoint_Config__mdt(
            Drive_Id__c = 'drive-id', Accounts_Parent_Item_Id__c = 'accounts-parent'
        );
        Test.setMock(HttpCalloutMock.class, new FolderMock());

        Test.startTest();
        new SharePointFolderCreationJob(new Set<Id>{ first.Id, second.Id }).execute(null);
        System.assertEquals(1, Limits.getQueueableJobs(), 'One continuation handles the remaining Account.');
        Test.stopTest();
    }
}
