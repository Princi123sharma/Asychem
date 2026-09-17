trigger AccountFolder on Account (after insert, after update) {
    if (Trigger.isAfter && Trigger.isInsert && !TriggerControlHelper.isBatchRunning) {
        for (Account accountRecord : Trigger.new) {
            if (accountRecord.Folder_Id__c == null) {
                BoxController.createAccountFolders(accountRecord.Id);
            }
        }
    }
}
