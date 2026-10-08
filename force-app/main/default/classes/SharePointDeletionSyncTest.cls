@IsTest
private class SharePointDeletionSyncTest {
    private class DeletedItemMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            System.assertEquals('GET', request.getMethod());
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"value":[{"id":"deleted-item","deleted":{}}],"@odata.deltaLink":"https://graph.microsoft.com/v1.0/drives/drive-id/root/delta?token=next"}');
            return response;
        }
    }

    private class BacklogPageMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody(
                '{"value":[],"@odata.nextLink":' +
                '"https://graph.microsoft.com/v1.0/drives/drive-id/root/delta?skiptoken=next-page"}'
            );
            return response;
        }
    }

    @IsTest
    static void removesTheContractFileLinkWhenTheCentralCdaCopyIsDeleted() {
        Account accountRecord = SharePointTestDataFactory.insertAccount('Deletion Sync Account');
        Contract contractRecord = SharePointTestDataFactory.insertReviewContract(accountRecord.Id);
        ContentVersion versionRecord = new ContentVersion(
            Title = 'deleted-file',
            PathOnClient = 'deleted-file.txt',
            VersionData = Blob.valueOf('file contents'),
            FirstPublishLocationId = contractRecord.Id
        );
        Boolean originalUploadSuppression = SharePointFileTriggerHandler.suppressUpload;
        try {
            // This test exercises deletion synchronization; it must not also
            // enqueue an unrelated upload from FirstPublishLocationId.
            SharePointFileTriggerHandler.suppressUpload = true;
            insert versionRecord;
        } finally {
            SharePointFileTriggerHandler.suppressUpload = originalUploadSuppression;
        }
        versionRecord = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :versionRecord.Id
        ];

        SharePoint_File_Link__c mapping = new SharePoint_File_Link__c(
            Name = 'deleted-file.txt',
            Content_Document_Id__c = String.valueOf(versionRecord.ContentDocumentId),
            Salesforce_Record_Id__c = String.valueOf(contractRecord.Id),
            SharePoint_Drive_Id__c = 'drive-id',
            SharePoint_Item_Id__c = 'deleted-item',
            SharePoint_Folder_Item_Id__c = 'central-cda-folder-id',
            SharePoint_File_Name__c = 'deleted-file.txt',
            Status__c = 'Active'
        );
        insert mapping;

        SharePointDeletionSync.configOverride = new SharePoint_Config__mdt(Drive_Id__c = 'drive-id');
        Test.setMock(HttpCalloutMock.class, new DeletedItemMock());

        Test.startTest();
        new SharePointDeletionSync().execute((QueueableContext) null);
        Test.stopTest();

        System.assertEquals(
            0,
            [
                SELECT Count()
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :versionRecord.ContentDocumentId
                AND LinkedEntityId = :contractRecord.Id
            ]
        );
        System.assertEquals(
            'DeletedFromSharePoint',
            [SELECT Status__c FROM SharePoint_File_Link__c WHERE Id = :mapping.Id].Status__c
        );
    }

    @IsTest
    static void checkpointsTheNextPageWhenThePageLimitIsReached() {
        SharePointDeletionSync.configOverride = new SharePoint_Config__mdt(Drive_Id__c = 'drive-id');
        SharePointDeletionSync.maxDeltaPagesOverride = 1;
        Test.setMock(HttpCalloutMock.class, new BacklogPageMock());

        try {
            new SharePointDeletionSync().execute((QueueableContext) null);
        } finally {
            SharePointDeletionSync.maxDeltaPagesOverride = null;
        }

        SharePoint_Sync_State__c state = [
            SELECT Delta_Link__c
            FROM SharePoint_Sync_State__c
            WHERE Name = 'Default'
            LIMIT 1
        ];
        System.assertEquals(
            'https://graph.microsoft.com/v1.0/drives/drive-id/root/delta?skiptoken=next-page',
            state.Delta_Link__c,
            'The next delta page must be persisted before a continuation is queued.'
        );
        System.assertEquals(1, Limits.getQueueableJobs());
    }
}
