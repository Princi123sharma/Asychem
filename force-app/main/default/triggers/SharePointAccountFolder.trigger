trigger SharePointAccountFolder on Account (after insert, after update) {
    AccountSharePointTriggerHandler.handleAfterInsertOrUpdate(Trigger.new);
}