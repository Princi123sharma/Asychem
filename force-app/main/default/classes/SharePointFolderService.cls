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

        if (!String.isBlank(account.SharePoint_Folder_Id__c)) {
            return;
        }

        String accountDisplayName = String.isNotBlank(account.Nick_Name__c)
            ? account.Nick_Name__c
            : account.Name;

        String accountFolderName = sanitizeFolderName(
            accountDisplayName + ' ' + String.valueOf(Date.today().year())
        );

        SharePointGraphClient.DriveItem accountFolder =
            SharePointGraphClient.createFolder(
                config.Drive_Id__c,
                config.Accounts_Parent_Item_Id__c,
                accountFolderName
            );

        SharePointGraphClient.DriveItem contractsFolder =
            SharePointGraphClient.createFolder(
                config.Drive_Id__c,
                accountFolder.id,
                'Legal Contracts'
            );

        SharePointGraphClient.DriveItem opportunitiesFolder =
            SharePointGraphClient.createFolder(
                config.Drive_Id__c,
                accountFolder.id,
                'Opportunities'
            );

        update new Account(
            Id = account.Id,
            SharePoint_Folder_Id__c = accountFolder.id,
            SharePoint_Contract_Folder_Id__c = contractsFolder.id,
            SharePoint_Opportunities_Folder_Id__c = opportunitiesFolder.id
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