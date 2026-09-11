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

    @IsTest
    static void removesTheContractFileLinkWhenTheCentralCdaCopyIsDeleted() {
        Account accountRecord = new Account(Name = 'Deletion Sync Account');
        insert accountRecord;
        Contract contractRecord = new Contract(
            AccountId = accountRecord.Id,
            StartDate = Date.today(),
            Status = 'Draft'
        );
        insert contractRecord;
        ContentVersion versionRecord = new ContentVersion(
            Title = 'deleted-file',
            PathOnClient = 'deleted-file.txt',
            VersionData = Blob.valueOf('file contents'),
            FirstPublishLocationId = contractRecord.Id
        );
        insert versionRecord;
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
}
