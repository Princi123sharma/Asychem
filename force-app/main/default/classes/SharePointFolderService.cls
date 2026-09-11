public with sharing class SharePointFolderService {
    public class SharePointFolderException extends Exception {}

    public static void createAccountFolders(Id accountId) {
        if (accountId == null) {
            throw new SharePointFolderException('Account ID is required.');
        }

        SharePoint_Config__mdt config =
            SharePoint_Config__mdt.getInstance('Default');

        if (config == null ||
            String.isBlank(config.Drive_Id__c) ||
            String.isBlank(config.Accounts_Parent_Item_Id__c)) {
            throw new SharePointFolderException(
                'SharePoint configuration is missing. Check the Default SharePoint Config metadata record.'
            );
        }

        Account account = [
            SELECT Id,
                   Name,
                   Nick_Name__c,
                   SharePoint_Folder_Id__c,
                   SharePoint_Contract_Folder_Id__c,
                   SharePoint_Opportunities_Folder_Id__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        String accountDisplayName = String.isNotBlank(account.Nick_Name__c)
            ? account.Nick_Name__c
            : account.Name;

        String accountFolderName = sanitizeFolderName(
            accountDisplayName + ' ' + String.valueOf(Date.today().year())
        );

        // Always resolve from the configured Accounts parent. This repairs
        // stale field values and ensures uploads use this Account's folder.
        String accountFolderId = getOrCreateFolderId(
            config.Drive_Id__c,
            config.Accounts_Parent_Item_Id__c,
            accountFolderName
        );
        if (String.isBlank(accountFolderId)) {
            throw new SharePointFolderException('Unable to resolve the Account SharePoint folder.');
        }

        String contractsFolderId = getOrCreateFolderId(
            config.Drive_Id__c,
            accountFolderId,
            'Contracts'
        );
        String opportunitiesFolderId = getOrCreateFolderId(
            config.Drive_Id__c,
            accountFolderId,
            'Opportunities'
        );

        update new Account(
            Id = account.Id,
            SharePoint_Folder_Id__c = accountFolderId,
            SharePoint_Contract_Folder_Id__c = contractsFolderId,
            SharePoint_Opportunities_Folder_Id__c = opportunitiesFolderId
        );
    }

    public static String resolveContractFolderName(String contractType, String contractStatus) {
        String normalizedType = String.isBlank(contractType) ? '' : contractType.trim();
        String normalizedStatus = String.isBlank(contractStatus) ? '' : contractStatus.trim();

        if (normalizedStatus == 'Active' && (
            normalizedType == '1-way CDA' ||
            normalizedType == '3-way CDA' ||
            normalizedType == '2-way CDA'
        )) {
            return 'CDA';
        }
        if (normalizedStatus == 'Active' && normalizedType == 'LOI') {
            return 'LOI';
        }
        if (normalizedStatus == 'Active' && normalizedType == 'MSA') {
            return 'MSA';
        }
        if (normalizedStatus == 'Active' && normalizedType == 'CSA') {
            return 'CSA';
        }
        if (normalizedStatus == 'Active' && normalizedType == 'QAA') {
            return 'QAA';
        }
        if (normalizedStatus == 'Executive Review') {
            return 'Executive Review';
        }
        if (normalizedStatus == 'Client Review') {
            return 'Client Review';
        }
        if (normalizedStatus == 'Internal Review') {
            return 'Internal Review';
        }

        return 'Misc';
    }

    /** Returns the configured central folder item ID for a Contract's routing rule. */
    public static String resolveCentralContractFolderId(
        SharePoint_Config__mdt config,
        String contractType,
        String contractStatus
    ) {
        if (config == null) return null;

        String folderName = resolveContractFolderName(contractType, contractStatus);
        if (folderName == 'CDA') {
            return String.isNotBlank(config.CDA_Folder_Item_Id__c)
                ? config.CDA_Folder_Item_Id__c
                : config.CDA_Item_ID__c;
        }
        if (folderName == 'LOI') {
            return String.isNotBlank(config.LOI_Folder_Item_Id__c)
                ? config.LOI_Folder_Item_Id__c
                : config.LOI_Item_ID__c;
        }
        if (folderName == 'MSA') {
            return String.isNotBlank(config.MSA_Folder_Item_Id__c)
                ? config.MSA_Folder_Item_Id__c
                : config.MSA_Item_ID__c;
        }
        if (folderName == 'CSA') {
            return String.isNotBlank(config.CSA_Folder_Item_Id__c)
                ? config.CSA_Folder_Item_Id__c
                : config.CSA_Item_ID__c;
        }
        if (folderName == 'QAA') {
            return String.isNotBlank(config.QAA_Folder_Item_Id__c)
                ? config.QAA_Folder_Item_Id__c
                : config.QAA_Item_ID__c;
        }
        if (folderName == 'Executive Review') {
            return String.isNotBlank(config.Executive_Review_Folder_Item_Id__c)
                ? config.Executive_Review_Folder_Item_Id__c
                : config.Executive_Review_Item_ID__c;
        }
        if (folderName == 'Client Review') {
            return String.isNotBlank(config.Client_Review_Folder_Item_Id__c)
                ? config.Client_Review_Folder_Item_Id__c
                : config.Client_Review_Item_ID__c;
        }
        if (folderName == 'Internal Review') {
            return String.isNotBlank(config.Internal_Review_Folder_Item_Id__c)
                ? config.Internal_Review_Folder_Item_Id__c
                : config.Internal_Review_Item_ID__c;
        }
        return String.isNotBlank(config.Misc_Folder_Item_Id__c)
            ? config.Misc_Folder_Item_Id__c
            : config.Misc_Item_ID__c;
    }

    public static String getOrCreateFolderId(
        String driveId,
        String parentFolderId,
        String folderName
    ) {
        if (String.isBlank(driveId) ||
            String.isBlank(parentFolderId) ||
            String.isBlank(folderName)) {
            return null;
        }

        String existingFolderId = SharePointGraphClient.getFolderIdByName(
            driveId,
            parentFolderId,
            folderName
        );
        if (String.isNotBlank(existingFolderId)) {
            return existingFolderId;
        }

        try {
            SharePointGraphClient.DriveItem item = SharePointGraphClient.createFolder(
                driveId,
                parentFolderId,
                folderName
            );
            return item != null ? item.id : null;
        } catch (SharePointGraphClient.SharePointException ex) {
            return SharePointGraphClient.getFolderIdByName(driveId, parentFolderId, folderName);
        }
    }

    private static String sanitizeFolderName(String name) {
        if (String.isBlank(name)) {
            return 'Unnamed Account';
        }

        return name.trim()
            .replace('/', ' ')
            .replace('\\', ' ')
            .replace(':', ' ')
            .replace('*', ' ')
            .replace('?', ' ')
            .replace('"', ' ')
            .replace('<', ' ')
            .replace('>', ' ')
            .replace('|', ' ')
            .replace('#', ' ')
            .replace('%', ' ');
    }
}
