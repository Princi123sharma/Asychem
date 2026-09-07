trigger AccountFolder on Account (after insert ) {
	Set<Id> accountsNeedingSharePointFolders = new Set<Id>();

    if (TriggerControlHelper.isBatchRunning) {
        // Skip execution if batch is running
        return;
    }
    
    for(Account temp : trigger.new){
        if(temp.Folder_Id__c == null)
        {
        	BoxController.createAccountFolders(temp.Id);
        }

        if (String.isBlank(temp.SharePoint_Folder_Id__c)) {
            accountsNeedingSharePointFolders.add(temp.Id);
        }
    }

    if (!accountsNeedingSharePointFolders.isEmpty()) {
        System.enqueueJob(
            new SharePointFolderCreationJob(accountsNeedingSharePointFolders)
        );
    }
}