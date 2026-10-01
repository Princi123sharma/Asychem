trigger SharePointAccountFolder on Account (after insert) {
    AccountSharePointTriggerHandler.handleAfterInsert(Trigger.new);
}
