trigger BoxFiles on ContentDocumentLink (after insert) {
    
    BoxController.handleFileUpload(trigger.new[0].Id);
    
}