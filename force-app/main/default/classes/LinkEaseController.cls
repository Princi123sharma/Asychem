/**
 * Direct, record-aware SharePoint uploads for the LinkEase LWC.
 *
 * This controller deliberately does not create ContentVersion or
 * ContentDocumentLink records. Files selected in LinkEase are sent only to
 * Microsoft Graph and therefore do not appear in Salesforce Files.
 */
public with sharing class LinkEaseController {
    private static final Integer MAX_FILE_SIZE_BYTES = 2 * 1024 * 1024;
    private static final Set<String> RESTRICTED_FILE_EXTENSIONS = new Set<String>{
        'exe', 'bat', 'cmd', 'scr'
    };
    @TestVisible private static SharePoint_Config__mdt configOverride;

    public class UploadResult {
        @AuraEnabled public String fileName { get; set; }
        @AuraEnabled public String driveItemId { get; set; }
        @AuraEnabled public String folderItemId { get; set; }
        @AuraEnabled public String message { get; set; }
    }

    public class SharePointFile {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Long size { get; set; }
        @AuraEnabled public String lastModifiedDateTime { get; set; }
        @AuraEnabled public String webUrl { get; set; }
    }

    @AuraEnabled
    public static List<SharePointFile> getFiles(Id recordId) {
        if (recordId == null) throwHandled('A record ID is required.');
        SharePoint_Config__mdt config = getConfig();
        if (config == null || String.isBlank(config.Drive_Id__c)) {
            throwHandled('SharePoint is not configured. Contact your administrator.');
        }

        List<String> folderIds = getTargetFolderIds(recordId, config);
        if (folderIds.isEmpty()) return new List<SharePointFile>();

        List<SharePointFile> result = new List<SharePointFile>();
        for (SharePointGraphClient.DriveItem item : SharePointGraphClient.listFiles(
            config.Drive_Id__c, folderIds[0]
        )) {
            SharePointFile file = new SharePointFile();
            file.id = item.id;
            file.name = item.name;
            file.size = item.size;
            file.lastModifiedDateTime = item.lastModifiedDateTime;
            file.webUrl = item.webUrl;
            result.add(file);
        }
        return result;
    }

    /**
     * Uploads one file directly to the SharePoint folder for the supplied
     * Account, Opportunity, or Contract record. The LWC calls this once per
     * selected file so Apex heap limits remain predictable.
     */
    @AuraEnabled
    public static UploadResult uploadFile(Id recordId, String fileName, String base64Data) {
        if (recordId == null) throwHandled('A record ID is required.');
        if (String.isBlank(fileName) || String.isBlank(base64Data)) {
            throwHandled('Select a file to upload.');
        }

        Blob fileData;
        try {
            fileData = EncodingUtil.base64Decode(base64Data);
        } catch (Exception exceptionRecord) {
            throwHandled('The selected file could not be read.');
            return null;
        }
        if (fileData == null || fileData.size() == 0) throwHandled('Empty files cannot be uploaded.');
        if (fileData.size() > MAX_FILE_SIZE_BYTES) {
            throwHandled('Each file must be 2 MB or smaller.');
        }

        String extension = fileName.contains('.') ? fileName.substringAfterLast('.').toLowerCase() : '';
        if (RESTRICTED_FILE_EXTENSIONS.contains(extension)) {
            throwHandled('This file type is not allowed.');
        }

        SharePoint_Config__mdt config = getConfig();
        if (config == null || String.isBlank(config.Drive_Id__c)) {
            throwHandled('SharePoint is not configured. Contact your administrator.');
        }

        List<String> folderIds = getTargetFolderIds(recordId, config);
        if (folderIds.isEmpty()) {
            throwHandled('No SharePoint folder is available for this record.');
        }

        try {
            SharePointGraphClient.DriveItem uploadedFile;
            for (String folderId : folderIds) {
                SharePointGraphClient.DriveItem uploadedItem = SharePointGraphClient.uploadFile(
                    config.Drive_Id__c, folderId, fileName, fileData
                );
                // folderItemId below identifies the first target folder, so return
                // the file item created in that same folder.
                if (folderId == folderIds[0]) {
                    uploadedFile = uploadedItem;
                }
            }

            UploadResult result = new UploadResult();
            result.fileName = fileName;
            result.driveItemId = uploadedFile == null ? null : uploadedFile.id;
            result.folderItemId = folderIds[0];
            result.message = 'Uploaded to SharePoint.';
            return result;
        } catch (Exception exceptionRecord) {
            throwHandled('SharePoint upload failed: ' + exceptionRecord.getMessage());
            return null;
        }
    }

    private static List<String> getTargetFolderIds(Id recordId, SharePoint_Config__mdt config) {
        Id accountId;
        Id opportunityId;
        Contract contractRecord;

        if (recordId.getSObjectType() == Account.SObjectType) {
            accountId = recordId;
        } else if (recordId.getSObjectType() == Opportunity.SObjectType) {
            Opportunity opportunityRecord = [SELECT AccountId FROM Opportunity WHERE Id = :recordId LIMIT 1];
            accountId = opportunityRecord.AccountId;
            opportunityId = recordId;
        } else if (recordId.getSObjectType() == Contract.SObjectType) {
            contractRecord = [
                SELECT AccountId, Type_of_Contract__c, Status
                FROM Contract WHERE Id = :recordId
                LIMIT 1
            ];
            accountId = contractRecord.AccountId;
        } else {
            throwHandled('LinkEase supports Account, Opportunity, and Contract records only.');
        }

        if (accountId == null) throwHandled('This record is not related to an Account.');
        Account accountRecord = getAccountWithFolders(accountId);
        if (String.isBlank(accountRecord.SharePoint_Folder_Id__c)) {
            try {
                SharePointFolderService.createAccountFolders(accountId);
                accountRecord = getAccountWithFolders(accountId);
            } catch (Exception exceptionRecord) {
                throwHandled('Unable to create the Account SharePoint folder: ' + exceptionRecord.getMessage());
            }
        }

        String accountFolderId = resolveAccountFolderId(accountRecord, config);
        Set<String> uniqueFolderIds = new Set<String>();
        if (opportunityId != null) addFolderId(
            uniqueFolderIds, accountRecord.SharePoint_Opportunities_Folder_Id__c
        );
        else if (contractRecord != null) {
            addFolderId(uniqueFolderIds, accountRecord.SharePoint_Contract_Folder_Id__c);
            addFolderId(
                uniqueFolderIds,
                SharePointFolderService.resolveCentralContractFolderId(
                    config,
                    contractRecord.Type_of_Contract__c,
                    contractRecord.Status
                )
            );
        } else addFolderId(uniqueFolderIds, accountFolderId);
        return new List<String>(uniqueFolderIds);
    }

    private static void addFolderId(Set<String> folderIds, String folderId) {
        if (String.isNotBlank(folderId)) folderIds.add(folderId);
    }

    /**
     * For an Account-page upload, prefer the folder currently found below the
     * configured Accounts parent. This prevents a stale Account field from
     * routing a file into another Account's SharePoint folder.
     */
    private static String resolveAccountFolderId(Account accountRecord, SharePoint_Config__mdt config) {
        if (String.isBlank(config.Accounts_Parent_Item_Id__c)) {
            return accountRecord.SharePoint_Folder_Id__c;
        }

        String accountDisplayName = String.isNotBlank(accountRecord.Nick_Name__c)
            ? accountRecord.Nick_Name__c
            : accountRecord.Name;
        String folderName = sanitizeFolderName(
            accountDisplayName + ' ' + String.valueOf(Date.today().year())
        );
        String resolvedFolderId = SharePointGraphClient.getFolderIdByName(
            config.Drive_Id__c, config.Accounts_Parent_Item_Id__c, folderName
        );
        return String.isNotBlank(resolvedFolderId)
            ? resolvedFolderId
            : accountRecord.SharePoint_Folder_Id__c;
    }

    private static Account getAccountWithFolders(Id accountId) {
        return [
            SELECT Name, Nick_Name__c, SharePoint_Folder_Id__c, SharePoint_Contract_Folder_Id__c,
                   SharePoint_Opportunities_Folder_Id__c
            FROM Account WHERE Id = :accountId LIMIT 1
        ];
    }

    private static String sanitizeFolderName(String name) {
        if (String.isBlank(name)) return 'Unnamed Account';
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

    private static SharePoint_Config__mdt getConfig() {
        return Test.isRunningTest() && configOverride != null
            ? configOverride
            : SharePoint_Config__mdt.getInstance('Default');
    }

    private static void throwHandled(String message) {
        AuraHandledException exceptionRecord = new AuraHandledException(message);
        exceptionRecord.setMessage(message);
        throw exceptionRecord;
    }
}
