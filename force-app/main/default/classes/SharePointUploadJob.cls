public with sharing class SharePointUploadJob implements Queueable, Database.AllowsCallouts {
    // One ContentVersion per transaction avoids heap, callout-body, and callout-count failures.
    private static final Integer MAX_UPLOAD_ATTEMPTS = 3;
    private static final Integer MAX_FOLDER_DEFERRALS = 3;
    private Map<Id, Set<Id>> documentToEntityIds;
    private List<UploadRequest> pendingUploads;
    private Integer folderDeferrals;

    public SharePointUploadJob(Map<Id, Set<Id>> documentToEntityIds) { this(documentToEntityIds, null, 0); }
    public SharePointUploadJob(Map<Id, Set<Id>> documentToEntityIds, Integer folderDeferrals) {
        this(documentToEntityIds, null, folderDeferrals);
    }
    private SharePointUploadJob(Map<Id, Set<Id>> input, List<UploadRequest> pending, Integer deferrals) {
        documentToEntityIds = new Map<Id, Set<Id>>();
        if (input != null) for (Id documentId : input.keySet()) {
            Set<Id> entities = input.get(documentId);
            if (entities != null && !entities.isEmpty()) documentToEntityIds.put(documentId, new Set<Id>(entities));
        }
        pendingUploads = pending;
        folderDeferrals = deferrals == null ? 0 : deferrals;
    }
    private SharePointUploadJob(List<UploadRequest> pending) { this(null, pending, 0); }

    public void execute(QueueableContext context) {
        SharePoint_Config__mdt config = SharePointFolderService.getConfiguration();
        if (config == null || String.isBlank(config.Drive_Id__c)) { recordAllInputFailures('Default SharePoint configuration has no Drive ID.'); return; }
        if (pendingUploads == null) {
            Set<Id> accountsNeedingFolders = findAccountsNeedingFolders();
            if (!accountsNeedingFolders.isEmpty()) {
                if (folderDeferrals >= MAX_FOLDER_DEFERRALS) { recordAllInputFailures('Account SharePoint folders were not created after ' + MAX_FOLDER_DEFERRALS + ' attempts.'); return; }
                System.enqueueJob(new SharePointFolderCreationJob(accountsNeedingFolders, documentToEntityIds, folderDeferrals + 1));
                return;
            }
        }
        List<UploadRequest> requests = pendingUploads == null ? buildUploadRequests(config) : pendingUploads;
        if (requests.isEmpty()) return;
        UploadRequest request = requests.remove(0);
        processOne(config, request);
        if (!requests.isEmpty()) System.enqueueJob(new SharePointUploadJob(requests));
    }

    private void processOne(SharePoint_Config__mdt config, UploadRequest request) {
        if (String.isBlank(request.folderItemId)) { recordFailure(config, request, 'No SharePoint folder is available for this record.'); return; }
        List<ContentVersion> versions = [SELECT ContentDocumentId, Title, FileExtension, ContentSize, VersionData FROM ContentVersion WHERE ContentDocumentId = :request.contentDocumentId AND IsLatest = true LIMIT 1];
        if (versions.isEmpty()) { recordFailure(config, request, 'The latest Salesforce file version is unavailable.'); return; }
        ContentVersion versionRecord = versions[0];
        String fileName = versionRecord.Title + (String.isNotBlank(versionRecord.FileExtension) ? '.' + versionRecord.FileExtension : '');
        if (versionRecord.ContentSize > SharePointGraphClient.SIMPLE_UPLOAD_MAX_BYTES) {
            publishLargeFileUpload(request, config.Drive_Id__c, fileName);
            SharePointFileLinkService.recordPendingLargeFileUpload(request.contentDocumentId, request.linkedEntityId, config.Drive_Id__c, request.folderItemId);
            return;
        }
        String validationError = validationError(versionRecord);
        if (validationError != null) { recordFailure(config, request, validationError); return; }
        UploadOutcome outcome = uploadWithRetry(config.Drive_Id__c, request.folderItemId, fileName, versionRecord.VersionData);
        // DML occurs only after all callout attempts have completed.
        if (outcome.uploadedItem != null) SharePointFileLinkService.recordUpload(request.contentDocumentId, request.linkedEntityId, config.Drive_Id__c, request.folderItemId, outcome.uploadedItem, fileName);
        else recordFailure(config, request, outcome.errorMessage);
    }

    private List<UploadRequest> buildUploadRequests(SharePoint_Config__mdt config) {
        List<UploadRequest> result = new List<UploadRequest>();
        if (documentToEntityIds.isEmpty()) return result;
        Set<Id> directAccountIds = new Set<Id>(), opportunityIds = new Set<Id>(), contractIds = new Set<Id>();
        for (Set<Id> entities : documentToEntityIds.values()) for (Id entityId : entities) {
            if (entityId.getSObjectType() == Account.SObjectType) directAccountIds.add(entityId);
            else if (entityId.getSObjectType() == Opportunity.SObjectType) opportunityIds.add(entityId);
            else if (entityId.getSObjectType() == Contract.SObjectType) contractIds.add(entityId);
        }
        Map<Id, Opportunity> opportunities = opportunityIds.isEmpty() ? new Map<Id, Opportunity>() : new Map<Id, Opportunity>([SELECT Id, AccountId FROM Opportunity WHERE Id IN :opportunityIds]);
        Map<Id, Contract> contracts = contractIds.isEmpty() ? new Map<Id, Contract>() : new Map<Id, Contract>([SELECT Id, AccountId, Type_of_Contract__c, Status FROM Contract WHERE Id IN :contractIds]);
        Set<Id> accountIds = new Set<Id>(directAccountIds);
        for (Opportunity record : opportunities.values()) if (record.AccountId != null) accountIds.add(record.AccountId);
        for (Contract record : contracts.values()) if (record.AccountId != null) accountIds.add(record.AccountId);
        Map<Id, Account> accounts = accountIds.isEmpty() ? new Map<Id, Account>() : new Map<Id, Account>([SELECT Id, SharePoint_Folder_Id__c, SharePoint_Contract_Folder_Id__c, SharePoint_Opportunities_Folder_Id__c FROM Account WHERE Id IN :accountIds]);
        for (Id documentId : documentToEntityIds.keySet()) for (Id entityId : documentToEntityIds.get(documentId)) {
            Set<String> folders = new Set<String>();
            if (entityId.getSObjectType() == Account.SObjectType) { Account account = accounts.get(entityId); addFolder(folders, account == null ? null : account.SharePoint_Folder_Id__c); }
            else if (entityId.getSObjectType() == Opportunity.SObjectType) { Opportunity record = opportunities.get(entityId); Account account = record == null ? null : accounts.get(record.AccountId); addFolder(folders, account == null ? null : account.SharePoint_Opportunities_Folder_Id__c); }
            else { Contract record = contracts.get(entityId); Account account = record == null ? null : accounts.get(record.AccountId); addFolder(folders, account == null ? null : account.SharePoint_Contract_Folder_Id__c); addFolder(folders, record == null ? null : SharePointFolderService.resolveCentralContractFolderId(config, record.Type_of_Contract__c, record.Status)); }
            if (folders.isEmpty()) result.add(new UploadRequest(documentId, entityId, null));
            for (String folderId : folders) result.add(new UploadRequest(documentId, entityId, folderId));
        }
        return result;
    }

    @TestVisible
    private Set<Id> findAccountsNeedingFolders() {
        Set<Id> accountIds = new Set<Id>();
        Set<Id> opportunityIds = new Set<Id>();
        Set<Id> contractIds = new Set<Id>();
        for (Set<Id> entities : documentToEntityIds.values()) for (Id entityId : entities) {
            if (entityId.getSObjectType() == Account.SObjectType) accountIds.add(entityId);
            else if (entityId.getSObjectType() == Opportunity.SObjectType) opportunityIds.add(entityId);
            else if (entityId.getSObjectType() == Contract.SObjectType) contractIds.add(entityId);
        }
        if (!opportunityIds.isEmpty()) {
            for (Opportunity record : [SELECT AccountId FROM Opportunity WHERE Id IN :opportunityIds]) {
                if (record.AccountId != null) accountIds.add(record.AccountId);
            }
        }
        if (!contractIds.isEmpty()) {
            for (Contract record : [SELECT AccountId FROM Contract WHERE Id IN :contractIds]) {
                if (record.AccountId != null) accountIds.add(record.AccountId);
            }
        }
        for (Account record : [
            SELECT Id, SharePoint_Folder_Id__c, SharePoint_Contract_Folder_Id__c,
                   SharePoint_Opportunities_Folder_Id__c
            FROM Account
            WHERE Id IN :accountIds
        ]) {
            if (String.isNotBlank(record.SharePoint_Folder_Id__c) &&
                String.isNotBlank(record.SharePoint_Contract_Folder_Id__c) &&
                String.isNotBlank(record.SharePoint_Opportunities_Folder_Id__c)) {
                accountIds.remove(record.Id);
            }
        }
        return accountIds;
    }
    private static void addFolder(Set<String> folders, String folderId) { if (String.isNotBlank(folderId)) folders.add(folderId); }
    private static void publishLargeFileUpload(UploadRequest request, String driveId, String fileName) {
        EventBus.publish(new SharePoint_Large_File__e(
            ContentDocumentId__c = String.valueOf(request.contentDocumentId),
            SalesforceRecordId__c = String.valueOf(request.linkedEntityId),
            DriveId__c = driveId,
            FolderIds__c = JSON.serialize(new List<String>{request.folderItemId}),
            FileName__c = fileName
        ));
    }
    private static String validationError(ContentVersion versionRecord) {
        if (versionRecord.VersionData == null) return 'The latest Salesforce file version is unavailable.';
        String extension = String.isBlank(versionRecord.FileExtension) ? '' : versionRecord.FileExtension.toLowerCase();
        return SharePointGraphClient.RESTRICTED_FILE_EXTENSIONS.contains(extension) ? 'File type ' + extension + ' is not allowed.' : null;
    }
    private static UploadOutcome uploadWithRetry(String driveId, String folderId, String fileName, Blob data) {
        UploadOutcome outcome = new UploadOutcome();
        for (Integer attempt = 1; attempt <= MAX_UPLOAD_ATTEMPTS; attempt++) try { outcome.uploadedItem = SharePointGraphClient.uploadFile(driveId, folderId, fileName, data); return outcome; } catch (Exception exceptionRecord) { outcome.errorMessage = exceptionRecord.getMessage(); }
        outcome.errorMessage = 'Upload failed after ' + MAX_UPLOAD_ATTEMPTS + ' attempts: ' + outcome.errorMessage;
        return outcome;
    }
    private static void recordFailure(SharePoint_Config__mdt config, UploadRequest request, String message) { SharePointFileLinkService.recordFailure(request.contentDocumentId, request.linkedEntityId, config.Drive_Id__c, request.folderItemId, message); }
    private void recordAllInputFailures(String message) { for (Id documentId : documentToEntityIds.keySet()) for (Id entityId : documentToEntityIds.get(documentId)) SharePointFileLinkService.recordFailure(documentId, entityId, null, null, message); }
    private class UploadOutcome { private SharePointGraphClient.DriveItem uploadedItem; private String errorMessage; }
    private class UploadRequest { private Id contentDocumentId, linkedEntityId; private String folderItemId; private UploadRequest(Id documentId, Id entityId, String folderId) { contentDocumentId = documentId; linkedEntityId = entityId; folderItemId = folderId; } }
}
