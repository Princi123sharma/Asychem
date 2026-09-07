trigger SharePointFiles on ContentDocumentLink (after insert) {
    SharePointFileTriggerHandler.handleAfterInsert(Trigger.new);
}
