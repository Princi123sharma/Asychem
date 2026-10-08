@IsTest
private class SharePointUploadJobTest {
    private static Integer uploadCallCount = 0;
    private class UploadMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            uploadCallCount++;
            HttpResponse response = new HttpResponse(); response.setStatusCode(201);
            response.setBody('{"id":"item-' + uploadCallCount + '","name":"file.txt","file":{}}'); return response;
        }
    }
    @IsTest static void uploadsOneFileToItsAccountFolder() {
        Account accountRecord = SharePointTestDataFactory.insertAccount('Upload Job');
        accountRecord.SharePoint_Folder_Id__c = 'account-folder'; TriggerControlHelper.isBatchRunning = true; update accountRecord; TriggerControlHelper.isBatchRunning = false;
        SharePointFileTriggerHandler.suppressUpload = true;
        ContentVersion first = new ContentVersion(Title='one', PathOnClient='one.txt', VersionData=Blob.valueOf('one'), FirstPublishLocationId=accountRecord.Id);
        insert first;
        SharePointFileTriggerHandler.suppressUpload = false;
        List<ContentVersion> versions = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :first.Id];
        Map<Id, Set<Id>> work = new Map<Id, Set<Id>>();
        for (ContentVersion versionRecord : versions) work.put(versionRecord.ContentDocumentId, new Set<Id>{accountRecord.Id});
        SharePointFolderService.configOverride = new SharePoint_Config__mdt(Drive_Id__c='drive-id');
        uploadCallCount = 0;
        Test.setMock(HttpCalloutMock.class, new UploadMock());
        Test.startTest();
        System.enqueueJob(new SharePointUploadJob(work));
        Test.stopTest();
        System.assertEquals(1, uploadCallCount);
        System.assertEquals(1, [SELECT Count() FROM SharePoint_File_Link__c WHERE Salesforce_Record_Id__c = :String.valueOf(accountRecord.Id)]);
    }

    @IsTest static void defersAccountAndOpportunityUploadsUntilFoldersExist() {
        Account accountRecord = SharePointTestDataFactory.insertAccount('Folder Deferral Account');
        Opportunity opportunityRecord = new Opportunity(
            Name = 'Folder Deferral Opportunity',
            AccountId = accountRecord.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today()
        );
        insert opportunityRecord;

        Map<Id, Set<Id>> accountWork = new Map<Id, Set<Id>>{
            accountRecord.Id => new Set<Id>{ accountRecord.Id }
        };
        Map<Id, Set<Id>> opportunityWork = new Map<Id, Set<Id>>{
            accountRecord.Id => new Set<Id>{ opportunityRecord.Id }
        };

        System.assertEquals(
            new Set<Id>{ accountRecord.Id },
            new SharePointUploadJob(accountWork).findAccountsNeedingFolders(),
            'An Account upload must wait until its folder structure exists.'
        );
        System.assertEquals(
            new Set<Id>{ accountRecord.Id },
            new SharePointUploadJob(opportunityWork).findAccountsNeedingFolders(),
            'An Opportunity upload must wait for its parent Account folders.'
        );
    }
}
