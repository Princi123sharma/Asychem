// Read-only diagnostic: reports only whether required configuration values exist.
SharePoint_Config__mdt cfg = SharePoint_Config__mdt.getInstance('Default');
System.debug(
    'CONFIG_PRESENT=' + (cfg != null) +
    ', DRIVE=' + (cfg != null && String.isNotBlank(cfg.Drive_Id__c)) +
    ', ACCOUNTS_PARENT=' + (cfg != null && String.isNotBlank(cfg.Accounts_Parent_Item_Id__c)) +
    ', CDA=' + (cfg != null && String.isNotBlank(cfg.CDA_Item_ID__c)) +
    ', CLIENT_REVIEW=' + (cfg != null && String.isNotBlank(cfg.Client_Review_Item_ID__c)) +
    ', EXEC_REVIEW=' + (cfg != null && String.isNotBlank(cfg.Executive_Review_Item_ID__c)) +
    ', INTERNAL_REVIEW=' + (cfg != null && String.isNotBlank(cfg.Internal_Review_Item_ID__c))
);
