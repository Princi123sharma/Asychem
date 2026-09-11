public with sharing class SharePointFileTriggerHandler {
    public static Boolean suppressUpload = false;

    public static void handleAfterInsert(List<ContentDocumentLink> links) {
        if (suppressUpload) return;
        Map<Id, Set<Id>> documentToEntityIds = new Map<Id, Set<Id>>();

        for (ContentDocumentLink link : links) {
            if (link.ContentDocumentId == null || link.LinkedEntityId == null) {
                continue;
            }

            SObjectType linkedObjectType = link.LinkedEntityId.getSObjectType();
            if (linkedObjectType != Account.SObjectType &&
                linkedObjectType != Opportunity.SObjectType &&
                linkedObjectType != Contract.SObjectType) {
                continue;
            }

            if (!documentToEntityIds.containsKey(link.ContentDocumentId)) {
                documentToEntityIds.put(link.ContentDocumentId, new Set<Id>());
            }
            documentToEntityIds.get(link.ContentDocumentId).add(link.LinkedEntityId);
        }

        if (!documentToEntityIds.isEmpty()) {
            System.enqueueJob(new SharePointUploadJob(documentToEntityIds));
        }
    }
}
