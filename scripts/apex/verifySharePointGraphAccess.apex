// Read-only connectivity verification. No folder or file is created.
SharePoint_Config__mdt cfg = SharePoint_Config__mdt.getInstance('Default');
try {
    List<SharePointGraphClient.DriveItem> children = SharePointGraphClient.listFolderContents(
        cfg.Drive_Id__c,
        cfg.Accounts_Parent_Item_Id__c
    );
    System.debug('GRAPH_ACCESS=SUCCESS, CHILD_COUNT=' + children.size());
} catch (Exception exceptionRecord) {
    System.debug('GRAPH_ACCESS=FAILED, TYPE=' + exceptionRecord.getTypeName() +
        ', MESSAGE=' + exceptionRecord.getMessage());
}
