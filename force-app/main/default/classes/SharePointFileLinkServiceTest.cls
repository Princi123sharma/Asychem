@IsTest
private class SharePointFileLinkServiceTest {
    private static ContentVersion createFile(Account accountRecord) {
        Boolean originalSuppression = SharePointFileTriggerHandler.suppressUpload;
        try {
            SharePointFileTriggerHandler.suppressUpload = true;
            ContentVersion versionRecord = new ContentVersion(
                Title = 'SharePoint link test',
                PathOnClient = 'sharepoint-link-test.txt',
                VersionData = Blob.valueOf('test file'),
                FirstPublishLocationId = accountRecord.Id
            );
            insert versionRecord;
            return [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :versionRecord.Id];
        } finally {
            SharePointFileTriggerHandler.suppressUpload = originalSuppression;
        }
    }

    @IsTest
    static void recordsAndUpdatesAnUploadedFileMapping() {
        Account accountRecord = SharePointTestDataFactory.insertAccount('File Link Upload');
        ContentVersion versionRecord = createFile(accountRecord);
        SharePointGraphClient.DriveItem uploadedItem = new SharePointGraphClient.DriveItem();
        uploadedItem.id = 'sharepoint-item-id';

        SharePointFileLinkService.recordUpload(
            versionRecord.ContentDocumentId, accountRecord.Id, 'drive-id', 'folder-id',
            uploadedItem, 'first-name.txt'
        );
        SharePointFileLinkService.recordUpload(
            versionRecord.ContentDocumentId, accountRecord.Id, 'drive-id', 'folder-id',
            uploadedItem, 'renamed-file.txt'
        );

        List<SharePoint_File_Link__c> mappings = [
            SELECT SharePoint_File_Name__c, Status__c
            FROM SharePoint_File_Link__c WHERE SharePoint_Item_Id__c = 'sharepoint-item-id'
        ];
        System.assertEquals(1, mappings.size());
        System.assertEquals('renamed-file.txt', mappings[0].SharePoint_File_Name__c);
        System.assertEquals('Active', mappings[0].Status__c);
    }

    @IsTest
    static void recordsFailureAndPendingLargeFileState() {
        Account accountRecord = SharePointTestDataFactory.insertAccount('File Link Failure');
        ContentVersion versionRecord = createFile(accountRecord);

        SharePointFileLinkService.recordFailure(
            versionRecord.ContentDocumentId, accountRecord.Id, 'drive-id', 'folder-id', 'Graph upload failed'
        );
        SharePointFileLinkService.recordPendingLargeFileUpload(
            versionRecord.ContentDocumentId, accountRecord.Id, 'drive-id', 'folder-id'
        );

        System.assertEquals(1, [
            SELECT Count() FROM SharePoint_File_Link__c
            WHERE Content_Document_Id__c = :String.valueOf(versionRecord.ContentDocumentId)
            AND Salesforce_Record_Id__c = :String.valueOf(accountRecord.Id)
            AND Status__c = 'Failed'
        ]);
        System.assertEquals(1, [
            SELECT Count() FROM SharePoint_Integration_Error__c
            WHERE Content_Document_Id__c = :String.valueOf(versionRecord.ContentDocumentId)
            AND Status__c = 'Failed'
        ]);
        System.assertEquals(1, [
            SELECT Count() FROM SharePoint_Integration_Error__c
            WHERE Content_Document_Id__c = :String.valueOf(versionRecord.ContentDocumentId)
            AND Status__c = 'PendingLargeFileUpload'
        ]);
    }
}
