trigger SharePointFileUploadDeferred on SharePoint_Deferred_File_Upload__e (after insert) {
    Map<Id, Set<Id>> uploads = new Map<Id, Set<Id>>();
    for (SharePoint_Deferred_File_Upload__e eventRecord : Trigger.new) {
        try {
            Id documentId = (Id) eventRecord.Content_Document_Id__c;
            Id recordId = (Id) eventRecord.Salesforce_Record_Id__c;
            if (!uploads.containsKey(documentId)) uploads.put(documentId, new Set<Id>());
            uploads.get(documentId).add(recordId);
        } catch (Exception ignored) { }
    }
    if (!uploads.isEmpty() && Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
        System.enqueueJob(new SharePointUploadJob(uploads));
    }
}
