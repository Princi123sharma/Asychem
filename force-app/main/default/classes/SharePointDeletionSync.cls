public without sharing class SharePointDeletionSync
    implements Queueable, Database.AllowsCallouts {

    private static final Integer MAX_DELTA_PAGES = 90;
    // The delta cursor is persisted on SharePoint_Sync_State__c between runs.
    @TestVisible private static SharePoint_Config__mdt configOverride;
    @TestVisible private static Integer maxDeltaPagesOverride;

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

        Integer pageLimit = Test.isRunningTest() && maxDeltaPagesOverride != null
            ? maxDeltaPagesOverride
            : MAX_DELTA_PAGES;
        while (pageCount < pageLimit) {
            lastResult = SharePointGraphClient.getDelta(
                config.Drive_Id__c, deltaLink, state.Id == null && String.isBlank(deltaLink)
            );
            pageCount += 1;
            for (SharePointGraphClient.DeltaItem item : lastResult.items) {
                if (item.deleted == true && String.isNotBlank(item.id)) {
                    deletedItemIds.add(item.id);
                }
            }
            if (String.isBlank(lastResult.nextLink)) break;
            deltaLink = lastResult.nextLink;
        }

        if (lastResult == null) return;

        // Apply the deletions processed in this run before checkpointing. If
        // the page cap was reached, nextLink resumes at the next unseen page.
        SharePointFileLinkService.removeLinksForDeletedItems(deletedItemIds);
        state.Drive_Id__c = config.Drive_Id__c;
        Boolean hasMorePages = String.isNotBlank(lastResult.nextLink);
        state.Delta_Link__c = hasMorePages ? lastResult.nextLink : lastResult.deltaLink;
        state.Last_Sync_Date__c = System.now();
        upsert state;

        if (hasMorePages) {
            System.debug(LoggingLevel.INFO, 'SharePoint deletion sync checkpointed at the page limit; queuing a continuation.');
            if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
                System.enqueueJob(new SharePointDeletionSync());
            }
        }
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
