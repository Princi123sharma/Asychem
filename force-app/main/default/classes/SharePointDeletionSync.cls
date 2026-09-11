public with sharing class SharePointDeletionSync
    implements Queueable, Database.AllowsCallouts {

    private static final Integer MAX_DELTA_PAGES = 90;
    @TestVisible private static SharePoint_Config__mdt configOverride;

    public void execute(QueueableContext context) {
        SharePoint_Config__mdt config = getConfig();
        if (config == null || String.isBlank(config.Drive_Id__c)) {
            System.debug(LoggingLevel.ERROR, 'SharePoint deletion sync skipped: Default configuration has no Drive ID.');
            return;
        }

        SharePoint_Sync_State__c state = getState(config.Drive_Id__c);
        String deltaLink = state.Delta_Link__c;
        Set<String> deletedItemIds = new Set<String>();
        SharePointGraphClient.DeltaResult lastResult;
        Integer pageCount = 0;

        while (pageCount < MAX_DELTA_PAGES) {
            lastResult = SharePointGraphClient.getDelta(config.Drive_Id__c, deltaLink);
            pageCount += 1;
            for (SharePointGraphClient.DeltaItem item : lastResult.items) {
                if (item.deleted == true && String.isNotBlank(item.id)) {
                    deletedItemIds.add(item.id);
                }
            }
            if (String.isBlank(lastResult.nextLink)) break;
            deltaLink = lastResult.nextLink;
        }

        if (lastResult == null || String.isNotBlank(lastResult.nextLink)) {
            System.debug(LoggingLevel.WARN, 'SharePoint deletion sync stopped before reaching a delta link.');
            return;
        }

        SharePointFileLinkService.removeLinksForDeletedItems(deletedItemIds);
        state.Drive_Id__c = config.Drive_Id__c;
        state.Delta_Link__c = lastResult.deltaLink;
        state.Last_Sync_Date__c = System.now();
        upsert state;
    }

    private static SharePoint_Config__mdt getConfig() {
        return Test.isRunningTest() && configOverride != null
            ? configOverride
            : SharePoint_Config__mdt.getInstance('Default');
    }

    private static SharePoint_Sync_State__c getState(String driveId) {
        List<SharePoint_Sync_State__c> states = [
            SELECT Id, Name, Drive_Id__c, Delta_Link__c, Last_Sync_Date__c
            FROM SharePoint_Sync_State__c
            WHERE Name = 'Default'
            LIMIT 1
        ];
        if (!states.isEmpty()) return states[0];
        return new SharePoint_Sync_State__c(
            Name = 'Default',
            Drive_Id__c = driveId
        );
    }
}
