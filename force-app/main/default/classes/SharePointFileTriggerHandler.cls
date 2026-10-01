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

        if (!documentToEntityIds.isEmpty() && Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
            System.enqueueJob(new SharePointUploadJob(documentToEntityIds));
        } else if (!documentToEntityIds.isEmpty()) {
            List<SharePoint_Deferred_File_Upload__e> deferredEvents = new List<SharePoint_Deferred_File_Upload__e>();
            for (Id documentId : documentToEntityIds.keySet()) {
                for (Id entityId : documentToEntityIds.get(documentId)) {
                    deferredEvents.add(new SharePoint_Deferred_File_Upload__e(
                        Content_Document_Id__c = String.valueOf(documentId),
                        Salesforce_Record_Id__c = String.valueOf(entityId)
                    ));
                }
            }
            EventBus.publish(deferredEvents);
        }
    }
}
