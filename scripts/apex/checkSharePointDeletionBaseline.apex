List<SharePoint_Sync_State__c> states = [
    SELECT Id, Delta_Link__c, Last_Sync_Date__c
    FROM SharePoint_Sync_State__c
    WHERE Name = 'Default'
    LIMIT 1
];
System.debug('DELETION_BASELINE_PRESENT=' + (!states.isEmpty() && String.isNotBlank(states[0].Delta_Link__c)));
