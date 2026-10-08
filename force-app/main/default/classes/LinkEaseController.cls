/**
 * Direct, record-aware SharePoint uploads for the LinkEase LWC.
 *
 * This controller deliberately does not create ContentVersion or
 * ContentDocumentLink records. Files selected in LinkEase are sent only to
 * Microsoft Graph and therefore do not appear in Salesforce Files.
 */
public with sharing class LinkEaseController {
    private static final Integer MAX_FILE_SIZE_BYTES = 50 * 1024 * 1024;
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

    public class SharePointFolder {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Boolean isFolder { get; set; }
        @AuraEnabled public Boolean isFallback { get; set; }
        @AuraEnabled public Long size { get; set; }
        @AuraEnabled public String lastModifiedDateTime { get; set; }
        @AuraEnabled public String lastModifiedBy { get; set; }
        @AuraEnabled public String webUrl { get; set; }
        @AuraEnabled public List<SharePointFolder> children { get; set; }
    }

    @AuraEnabled
    public static SharePointFolder getFolderTree(Id recordId) {
        String defaultFolderId = getDefaultFolderId(recordId);
        SharePointFolder folder = getFolderContents(recordId, defaultFolderId);
        if (String.isBlank(defaultFolderId) && recordId.getSObjectType() != Account.SObjectType) {
            String childFolderName = recordId.getSObjectType() == Contract.SObjectType
                ? 'Contracts'
                : 'Opportunities';
            for (SharePointFolder child : folder.children) {
                if (child.isFolder && child.name == childFolderName) {
                    folder = getFolderContents(recordId, child.id);
                    defaultFolderId = child.id;
                    break;
                }
            }
        }
        if (String.isNotBlank(defaultFolderId) && recordId.getSObjectType() == Contract.SObjectType) {
            folder.name = 'Contracts';
        } else if (String.isNotBlank(defaultFolderId) && recordId.getSObjectType() == Opportunity.SObjectType) {
            folder.name = 'Opportunities';
        }
        return folder;
    }

    /**
     * Requests a background repair for legacy Accounts whose SharePoint folder
     * exists but whose folder IDs were never saved in Salesforce. LinkEase
     * remains read-only; the Queueable performs the reconciliation.
     */
    @AuraEnabled
    public static void requestFolderReconciliation(Id recordId) {
        if (recordId == null) throwHandled('A record ID is required.');
        Id accountId = getAccountId(recordId);
        if (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) {
            throwHandled('Folder preparation is queued; refresh in a moment.');
        }
        System.enqueueJob(new SharePointFolderCreationJob(new Set<Id>{ accountId }));
    }

    @AuraEnabled
    public static String getFileDownloadUrl(Id recordId, String itemId) {
        if (recordId == null || String.isBlank(itemId)) {
            throwHandled('Select a file to download.');
        }
        SharePoint_Config__mdt config = getConfig();
        if (config == null || String.isBlank(config.Drive_Id__c)) {
            throwHandled('SharePoint is not configured. Contact your administrator.');
        }
        assertItemBelongsToRecord(recordId, itemId, config);
        String downloadUrl = SharePointGraphClient.getItemDownloadUrl(config.Drive_Id__c, itemId);
        if (String.isBlank(downloadUrl)) {
            throwHandled('The selected file is unavailable for download.');
        }
        return downloadUrl;
    }

    /** Deletes files selected in the LinkEase folder currently shown to the user. */
    @AuraEnabled
    public static void deleteFiles(Id recordId, String folderItemId, List<String> itemIds) {
        if (recordId == null || String.isBlank(folderItemId) || itemIds == null || itemIds.isEmpty()) {
            throwHandled('Select at least one file to delete.');
        }
        SharePoint_Config__mdt config = getConfig();
        if (config == null || String.isBlank(config.Drive_Id__c)) {
            throwHandled('SharePoint is not configured. Contact your administrator.');
        }

        // Ensure the caller is operating on a supported Salesforce record and
        // delete only items that are actually children of the displayed folder.
        assertItemBelongsToRecord(recordId, folderItemId, config);
        Set<String> requestedIds = new Set<String>(itemIds);
        Set<String> itemIdsToDelete = new Set<String>();
        for (SharePointGraphClient.DriveItem item : SharePointGraphClient.listFolderContents(
            config.Drive_Id__c, folderItemId
        )) {
            if (item.isFolder != true && requestedIds.contains(item.id)) {
                itemIdsToDelete.add(item.id);
            }
        }
        if (itemIdsToDelete.size() != requestedIds.size()) {
            throwHandled('One or more selected files are no longer in this SharePoint folder. Refresh and try again.');
        }

        // Contract uploads can create a second copy in a shared central folder.
        // There is no persisted relationship between those copies, so never
        // infer a counterpart from its filename: duplicate names can belong to
        // another Account. Delete only the exact item selected in this folder.
        for (String itemId : itemIdsToDelete) {
            SharePointGraphClient.deleteItem(config.Drive_Id__c, itemId);
        }
    }

    @AuraEnabled
    public static SharePointFolder getFolderContents(Id recordId, String folderItemId) {
        if (recordId == null) throwHandled('A record ID is required.');
        SharePoint_Config__mdt config = getConfig();
        if (config == null || String.isBlank(config.Drive_Id__c)) {
            throwHandled('SharePoint is not configured. Contact your administrator.');
        }

        Id accountId = getAccountId(recordId);
        Account accountRecord = getAccountWithFolders(accountId);
        String rootFolderId = accountRecord.SharePoint_Folder_Id__c;
        Boolean usedFallback = false;
        if (String.isBlank(rootFolderId)) {
            rootFolderId = findExistingAccountFolderId(config, accountRecord);
            usedFallback = String.isNotBlank(rootFolderId);
        }
        if (String.isBlank(rootFolderId)) {
            throwHandled('SharePoint folders are being prepared for this Account. Refresh in a moment.');
        }
        if (String.isNotBlank(folderItemId)) assertDescendsFrom(config, folderItemId, rootFolderId);

        String accountDisplayName = String.isNotBlank(accountRecord.Nick_Name__c)
            ? accountRecord.Nick_Name__c
            : accountRecord.Name;
        Boolean listingRoot = String.isBlank(folderItemId) || folderItemId == rootFolderId;
        SharePointFolder folder = new SharePointFolder();
        folder.id = listingRoot ? rootFolderId : folderItemId;
        folder.isFallback = usedFallback;
        folder.name = listingRoot
            ? sanitizeFolderName(accountDisplayName + ' ' + String.valueOf(Date.today().year()))
            : null;
        folder.isFolder = true;
        folder.webUrl = SharePointGraphClient.getItemWebUrl(config.Drive_Id__c, folder.id);
        folder.children = listChildren(config.Drive_Id__c, folder.id);
        return folder;
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
    public static UploadResult uploadFile(Id recordId, String fileName, String base64Data, String folderItemId) {
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
            throwHandled('Each file must be 50 MB or smaller.');
        }

        String extension = fileName.contains('.') ? fileName.substringAfterLast('.').toLowerCase() : '';
        if (SharePointGraphClient.RESTRICTED_FILE_EXTENSIONS.contains(extension)) {
            throwHandled('This file type is not allowed.');
        }

        SharePoint_Config__mdt config = getConfig();
        if (config == null || String.isBlank(config.Drive_Id__c)) {
            throwHandled('SharePoint is not configured. Contact your administrator.');
        }

        List<String> folderIds = getUploadFolderIds(recordId, config, folderItemId);
        if (folderIds.isEmpty()) {
            throwHandled('No SharePoint folder is available for this record.');
        }

        SharePointGraphClient.DriveItem uploadedFile;
        List<String> failedFolders = new List<String>();
        for (String folderId : folderIds) {
            try {
                SharePointGraphClient.DriveItem uploadedItem = SharePointGraphClient.uploadFile(
                    config.Drive_Id__c, folderId, fileName, fileData, 'rename'
                );
                if (uploadedFile == null) uploadedFile = uploadedItem;
            } catch (Exception exceptionRecord) {
                failedFolders.add(folderId + ': ' + exceptionRecord.getMessage());
            }
        }

        if (uploadedFile == null) {
            throwHandled(
                'SharePoint upload failed: ' +
                (failedFolders.isEmpty() ? 'No SharePoint folder accepted the file.' : failedFolders[0])
            );
        }
        if (!failedFolders.isEmpty()) {
            throwHandled(
                'The file was uploaded to one SharePoint folder, but another destination failed: ' +
                failedFolders[0]
            );
        }

        UploadResult result = new UploadResult();
        result.fileName = fileName;
        result.driveItemId = uploadedFile.id;
        result.folderItemId = folderIds[0];
        result.message = folderIds.size() > 1
            ? 'Uploaded to SharePoint (Account folder and central contract folder).'
            : 'Uploaded to SharePoint.';
        return result;
    }

    @AuraEnabled
    public static UploadSessionResult createUploadSession(Id recordId, String fileName, String folderItemId, Long totalSize) {
        if (recordId == null || String.isBlank(fileName)) throwHandled('A record and file name are required.');
        if (totalSize == null || totalSize <= 0 || totalSize > MAX_FILE_SIZE_BYTES) throwHandled('Each file must be 50 MB or smaller.');
        String extension = fileName.contains('.') ? fileName.substringAfterLast('.').toLowerCase() : '';
        if (SharePointGraphClient.RESTRICTED_FILE_EXTENSIONS.contains(extension)) throwHandled('This file type is not allowed.');
        SharePoint_Config__mdt config = getConfig();
        if (config == null || String.isBlank(config.Drive_Id__c)) throwHandled('SharePoint is not configured. Contact your administrator.');
        List<String> folderIds = getUploadFolderIds(recordId, config, folderItemId);
        if (folderIds.isEmpty()) throwHandled('No SharePoint folder is available for this record.');
        List<SharePoint_Upload_Session__c> sessions = new List<SharePoint_Upload_Session__c>();
        for (String folderId : folderIds) {
            sessions.add(new SharePoint_Upload_Session__c(
                Upload_Url__c = SharePointGraphClient.createUploadSession(
                    config.Drive_Id__c, folderId, fileName, 'rename'
                ),
                Total_Size__c = totalSize,
                Next_Byte__c = 0, Status__c = 'Active', Expires_At__c = System.now().addHours(1)
            ));
        }
        insert sessions;
        UploadSessionResult result = new UploadSessionResult();
        result.sessionIds = new List<Id>();
        for (SharePoint_Upload_Session__c sessionRecord : sessions) result.sessionIds.add(sessionRecord.Id);
        return result;
    }

    @AuraEnabled
    public static String uploadChunk(Id sessionId, String base64Data, Long start, Long total) {
        if (sessionId == null || String.isBlank(base64Data) || start == null || total == null) {
            throwHandled('Upload chunk data is incomplete.');
        }
        Blob chunk;
        try { chunk = EncodingUtil.base64Decode(base64Data); }
        catch (Exception e) { throwHandled('The upload chunk could not be read.'); return null; }
        if (chunk.size() > 4 * 320 * 1024) throwHandled('Upload chunks must be 1.25 MB or smaller.');
        SharePoint_Upload_Session__c sessionRecord = [
            SELECT Upload_Url__c, Next_Byte__c, Total_Size__c, OwnerId, Status__c, Expires_At__c
            FROM SharePoint_Upload_Session__c WHERE Id = :sessionId LIMIT 1
        ];
        if (sessionRecord.OwnerId != UserInfo.getUserId()) throwHandled('You cannot use this upload session.');
        if (sessionRecord.Status__c != 'Active' || sessionRecord.Expires_At__c <= System.now()) throwHandled('This upload session has expired. Start again.');
        if (sessionRecord.Total_Size__c.longValue() != total || sessionRecord.Next_Byte__c.longValue() != start) throwHandled('Upload chunks are out of sequence.');
        if (total <= 0 || total > MAX_FILE_SIZE_BYTES) throwHandled('Each file must be 50 MB or smaller.');
        if (start < 0 || start + chunk.size() > total) throwHandled('Upload chunk size does not match the file size. Start again.');
        // Microsoft Graph requires every chunk except the final one to be a
        // multiple of 320 KiB. The LWC uses 1.25 MB (4 x 320 KiB).
        if (start + chunk.size() < total && Math.mod(chunk.size(), 320 * 1024) != 0) {
            throwHandled('Upload chunk size is invalid. Start the upload again.');
        }
        String response;
        try {
            response = SharePointGraphClient.uploadChunk(sessionRecord.Upload_Url__c, chunk, start, total);
        } catch (Exception exceptionRecord) {
            sessionRecord.Status__c = 'Failed';
            update sessionRecord;
            throwHandled('A SharePoint upload chunk failed. Please retry the file. ' + exceptionRecord.getMessage());
            return null;
        }
        sessionRecord.Next_Byte__c = start + chunk.size();
        if (sessionRecord.Next_Byte__c.longValue() == total) sessionRecord.Status__c = 'Completed';
        update sessionRecord;
        return response;
    }

    private static List<String> getTargetFolderIds(Id recordId, SharePoint_Config__mdt config) {
        Id accountId = getAccountId(recordId);
        Id opportunityId;
        Contract contractRecord;

        if (recordId.getSObjectType() == Opportunity.SObjectType) {
            opportunityId = recordId;
        } else if (recordId.getSObjectType() == Contract.SObjectType) {
            contractRecord = [
                SELECT AccountId, Type_of_Contract__c, Status
                FROM Contract WHERE Id = :recordId
                LIMIT 1
            ];
        }

        if (accountId == null) throwHandled('This record is not related to an Account.');
        Account accountRecord = getAccountWithFolders(accountId);
        if (String.isBlank(accountRecord.SharePoint_Folder_Id__c)) {
            throwHandled('SharePoint folders are being prepared for this Account. Refresh in a moment.');
        }

        String accountFolderId = accountRecord.SharePoint_Folder_Id__c;
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

    /** Selects the default LinkEase folder for the page's record type. */
    private static String getDefaultFolderId(Id recordId) {
        if (recordId == null || recordId.getSObjectType() == Account.SObjectType) return null;

        Id accountId = getAccountId(recordId);
        Account accountRecord = getAccountWithFolders(accountId);
        if (recordId.getSObjectType() == Contract.SObjectType) {
            return accountRecord.SharePoint_Contract_Folder_Id__c;
        }
        if (recordId.getSObjectType() == Opportunity.SObjectType) {
            return accountRecord.SharePoint_Opportunities_Folder_Id__c;
        }
        return null;
    }

    /**
     * Legacy fallback only: find exactly one matching Account folder under the
     * configured Accounts parent. This never creates folders or writes data.
     */
    private static String findExistingAccountFolderId(
        SharePoint_Config__mdt config,
        Account accountRecord
    ) {
        if (config == null || String.isBlank(config.Drive_Id__c) ||
            String.isBlank(config.Accounts_Parent_Item_Id__c)) return null;

        String accountDisplayName = String.isNotBlank(accountRecord.Nick_Name__c)
            ? accountRecord.Nick_Name__c
            : accountRecord.Name;
        String expectedName = SharePointFolderService.sanitizeFolderName(
            accountDisplayName + ' ' + String.valueOf(Date.today().year())
        );
        List<SharePointGraphClient.DriveItem> matches = new List<SharePointGraphClient.DriveItem>();
        for (SharePointGraphClient.DriveItem item : SharePointGraphClient.listFolderContents(
            config.Drive_Id__c, config.Accounts_Parent_Item_Id__c
        )) {
            if (item.isFolder && item.name == expectedName) matches.add(item);
        }
        return matches.size() == 1 ? matches[0].id : null;
    }

    /**
     * When LinkEase is opened from an Account record, users can browse into its
     * Contracts or Opportunities folders. Respect that active folder for the
     * upload rather than routing the file back to the Account root folder.
     */
    private static List<String> getUploadFolderIds(
        Id recordId,
        SharePoint_Config__mdt config,
        String folderItemId
    ) {
        // From an Account record, browsing into Contracts or Opportunities is
        // view-only. Account-page uploads always go to the Account root.
        if (recordId != null && recordId.getSObjectType() == Account.SObjectType) {
            return getTargetFolderIds(recordId, config);
        }
        // Contract files are mandatory copies: one goes to the parent
        // Account's Contracts folder and one to the central Legal Contracts
        // folder selected from Contract type and status. The LWC supplies the
        // currently displayed Account Contracts folder, but that must not
        // suppress the central copy.
        if (recordId != null && recordId.getSObjectType() == Contract.SObjectType) {
            return getTargetFolderIds(recordId, config);
        }
        return getTargetFolderIds(recordId, config);
    }

    private static Id getAccountId(Id recordId) {
        if (recordId.getSObjectType() == Account.SObjectType) return recordId;
        if (recordId.getSObjectType() == Opportunity.SObjectType) {
            return [SELECT AccountId FROM Opportunity WHERE Id = :recordId LIMIT 1].AccountId;
        }
        if (recordId.getSObjectType() == Contract.SObjectType) {
            return [SELECT AccountId FROM Contract WHERE Id = :recordId LIMIT 1].AccountId;
        }
        throwHandled('LinkEase supports Account, Opportunity, and Contract records only.');
        return null;
    }

    private static List<SharePointFolder> listChildren(String driveId, String folderId) {
        List<SharePointFolder> result = new List<SharePointFolder>();
        for (SharePointGraphClient.DriveItem item : SharePointGraphClient.listFolderContents(driveId, folderId)) {
            SharePointFolder node = new SharePointFolder();
            node.id = item.id;
            node.name = item.name;
            node.isFolder = item.isFolder == true;
            node.size = item.size;
            node.lastModifiedDateTime = item.lastModifiedDateTime;
            node.lastModifiedBy = item.lastModifiedBy;
            node.webUrl = item.webUrl;
            node.children = new List<SharePointFolder>();
            result.add(node);
        }
        return result;
    }

    private static void addFolderId(Set<String> folderIds, String folderId) {
        if (String.isNotBlank(folderId)) folderIds.add(folderId);
    }
    public class UploadSessionResult {
        @AuraEnabled public List<Id> sessionIds { get; set; }
    }
    public class FolderReadiness { @AuraEnabled public Boolean isReady { get; set; } }

    @AuraEnabled(cacheable=true)
    public static FolderReadiness getFolderReadiness(Id recordId) {
        Id accountId = getAccountId(recordId);
        Account accountRecord = getAccountWithFolders(accountId);
        FolderReadiness result = new FolderReadiness();
        result.isReady = String.isNotBlank(accountRecord.SharePoint_Folder_Id__c) &&
            String.isNotBlank(accountRecord.SharePoint_Contract_Folder_Id__c) &&
            String.isNotBlank(accountRecord.SharePoint_Opportunities_Folder_Id__c);
        return result;
    }

    private static void assertItemBelongsToRecord(Id recordId, String itemId, SharePoint_Config__mdt config) {
        Account accountRecord = getAccountWithFolders(getAccountId(recordId));
        if (String.isBlank(accountRecord.SharePoint_Folder_Id__c)) throwHandled('SharePoint folders are being prepared for this Account. Refresh in a moment.');
        assertDescendsFrom(config, itemId, accountRecord.SharePoint_Folder_Id__c);
    }

    /** Never trust an item ID supplied by the browser: verify its complete ancestry. */
    private static void assertDescendsFrom(SharePoint_Config__mdt config, String itemId, String rootFolderId) {
        String currentId = itemId;
        for (Integer depth = 0; depth < 50 && String.isNotBlank(currentId); depth++) {
            if (currentId == rootFolderId) return;
            currentId = SharePointGraphClient.getParentItemId(config.Drive_Id__c, currentId);
        }
        throwHandled('This SharePoint item is not in the folder assigned to this record.');
    }

    private static Account getAccountWithFolders(Id accountId) {
        return [
            SELECT Name, Nick_Name__c, SharePoint_Folder_Id__c, SharePoint_Contract_Folder_Id__c,
                   SharePoint_Opportunities_Folder_Id__c
            FROM Account WHERE Id = :accountId LIMIT 1
        ];
    }

    private static String sanitizeFolderName(String name) {
        return SharePointFolderService.sanitizeFolderName(name);
    }

    private static SharePoint_Config__mdt getConfig() {
        if (Test.isRunningTest() && configOverride != null) return configOverride;
        List<SharePoint_Config__mdt> configs = [
            SELECT Drive_Id__c, Accounts_Parent_Item_Id__c,
                   CDA_Folder_Item_Id__c, CDA_Item_ID__c,
                   LOI_Folder_Item_Id__c, LOI_Item_ID__c,
                   MSA_Folder_Item_Id__c, MSA_Item_ID__c,
                   CSA_Folder_Item_Id__c, CSA_Item_ID__c,
                   QAA_Folder_Item_Id__c, QAA_Item_ID__c,
                   Executive_Review_Folder_Item_Id__c, Executive_Review_Item_ID__c,
                   Client_Review_Folder_Item_Id__c, Client_Review_Item_ID__c,
                   Internal_Review_Folder_Item_Id__c, Internal_Review_Item_ID__c,
                   Misc_Folder_Item_Id__c, Misc_Item_ID__c
            FROM SharePoint_Config__mdt
            WHERE DeveloperName = 'Default'
            LIMIT 1
        ];
        return configs.isEmpty() ? null : configs[0];
    }

    private static void throwHandled(String message) {
        AuraHandledException exceptionRecord = new AuraHandledException(message);
        exceptionRecord.setMessage(message);
        throw exceptionRecord;
    }
}
