public with sharing class SharePointFileLinkService {
    public static void recordUpload(
        Id contentDocumentId,
        Id linkedEntityId,
        String driveId,
        String folderItemId,
        SharePointGraphClient.DriveItem uploadedItem,
        String fileName
    ) {
        if (contentDocumentId == null || linkedEntityId == null ||
            String.isBlank(driveId) || String.isBlank(folderItemId) ||
            uploadedItem == null || String.isBlank(uploadedItem.id)) {
            return;
        }

        List<SharePoint_File_Link__c> existingLinks = [
            SELECT Id
            FROM SharePoint_File_Link__c
            WHERE SharePoint_Item_Id__c = :uploadedItem.id
            LIMIT 1
        ];
        SharePoint_File_Link__c linkRecord = existingLinks.isEmpty()
            ? new SharePoint_File_Link__c()
            : existingLinks[0];
        linkRecord.Name = buildName(fileName, uploadedItem.id);
        linkRecord.Content_Document_Id__c = String.valueOf(contentDocumentId);
        linkRecord.Salesforce_Record_Id__c = String.valueOf(linkedEntityId);
        linkRecord.SharePoint_Drive_Id__c = driveId;
        linkRecord.SharePoint_Item_Id__c = uploadedItem.id;
        linkRecord.SharePoint_Folder_Item_Id__c = folderItemId;
        linkRecord.SharePoint_File_Name__c = fileName;
        linkRecord.Status__c = 'Active';
        upsert linkRecord;
    }

    public static void removeLinksForDeletedItems(Set<String> sharePointItemIds) {
        if (sharePointItemIds == null || sharePointItemIds.isEmpty()) return;

        List<SharePoint_File_Link__c> mappings = [
            SELECT Id, Content_Document_Id__c, Salesforce_Record_Id__c
            FROM SharePoint_File_Link__c
            WHERE SharePoint_Item_Id__c IN :sharePointItemIds
            AND Status__c = 'Active'
        ];
        if (mappings.isEmpty()) return;

        Set<Id> documentIds = new Set<Id>();
        Set<Id> recordIds = new Set<Id>();
        for (SharePoint_File_Link__c mapping : mappings) {
            Id documentId = parseId(mapping.Content_Document_Id__c);
            Id recordId = parseId(mapping.Salesforce_Record_Id__c);
            if (documentId != null) documentIds.add(documentId);
            if (recordId != null) recordIds.add(recordId);
        }

        List<ContentDocumentLink> linksToDelete = new List<ContentDocumentLink>();
        if (!documentIds.isEmpty() && !recordIds.isEmpty()) {
            for (ContentDocumentLink link : [
                SELECT Id, ContentDocumentId, LinkedEntityId
                FROM ContentDocumentLink
                WHERE ContentDocumentId IN :documentIds
                AND LinkedEntityId IN :recordIds
            ]) {
                for (SharePoint_File_Link__c mapping : mappings) {
                    if (String.valueOf(link.ContentDocumentId) == mapping.Content_Document_Id__c &&
                        String.valueOf(link.LinkedEntityId) == mapping.Salesforce_Record_Id__c) {
                        linksToDelete.add(link);
                        break;
                    }
                }
            }
        }
        if (!linksToDelete.isEmpty()) delete linksToDelete;

        for (SharePoint_File_Link__c mapping : mappings) {
            mapping.Status__c = 'DeletedFromSharePoint';
        }
        update mappings;
    }

    private static Id parseId(String value) {
        if (String.isBlank(value)) return null;
        try {
            return (Id) value;
        } catch (Exception exceptionRecord) {
            return null;
        }
    }

    private static String buildName(String fileName, String itemId) {
        String value = String.isBlank(fileName) ? itemId : fileName;
        return value.length() > 80 ? value.substring(0, 80) : value;
    }
}
