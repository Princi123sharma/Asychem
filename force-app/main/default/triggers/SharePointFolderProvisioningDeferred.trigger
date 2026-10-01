trigger SharePointFolderProvisioningDeferred on SharePoint_Folder_Provisioning__e (after insert) {
    Set<Id> accountIds = new Set<Id>();
    for (SharePoint_Folder_Provisioning__e eventRecord : Trigger.new) {
        try { accountIds.add((Id) eventRecord.Account_Id__c); } catch (Exception ignored) { }
    }
    if (!accountIds.isEmpty() && Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
        System.enqueueJob(new SharePointFolderCreationJob(accountIds));
    }
}
