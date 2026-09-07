public with sharing class SharePointUploadJob
    implements Queueable, Database.AllowsCallouts {

    private static final Integer UPLOADS_PER_JOB = 100;
    private static final Integer MAX_FILE_SIZE_BYTES = 50 * 1024 * 1024;
    private static final Integer MAX_UPLOAD_ATTEMPTS = 3;
    private static final Set<String> RESTRICTED_FILE_EXTENSIONS = new Set<String>{
        'exe', 'bat', 'cmd', 'scr'
    };

    private Map<Id, Set<Id>> documentToEntityIds;
    private List<UploadRequest> pendingUploads;

    public SharePointUploadJob(Map<Id, Set<Id>> documentToEntityIds) {
        this.documentToEntityIds = new Map<Id, Set<Id>>();
        if (documentToEntityIds == null) return;
        for (Id documentId : documentToEntityIds.keySet()) {
            Set<Id> entityIds = documentToEntityIds.get(documentId);
            if (entityIds != null && !entityIds.isEmpty()) {
                this.documentToEntityIds.put(documentId, new Set<Id>(entityIds));
            }
        }
    }

    private SharePointUploadJob(List<UploadRequest> pendingUploads) {
        this.documentToEntityIds = new Map<Id, Set<Id>>();
        this.pendingUploads = pendingUploads;
    }

    public void execute(QueueableContext context) {
        SharePoint_Config__mdt config = SharePoint_Config__mdt.getInstance('Default');
        if (config == null || String.isBlank(config.Drive_Id__c)) {
            System.debug(LoggingLevel.ERROR, 'SharePoint upload skipped: Default configuration has no Drive ID.');
            return;
        }

        List<UploadRequest> uploadRequests = pendingUploads;
        if (uploadRequests == null) uploadRequests = buildUploadRequests(config);
        if (uploadRequests.isEmpty()) return;

        List<UploadRequest> uploadsForThisJob = new List<UploadRequest>();
        List<UploadRequest> remainingUploads = new List<UploadRequest>();
        for (Integer index = 0; index < uploadRequests.size(); index++) {
            if (index < UPLOADS_PER_JOB) uploadsForThisJob.add(uploadRequests[index]);
            else remainingUploads.add(uploadRequests[index]);
        }

        Set<Id> documentIds = new Set<Id>();
        for (UploadRequest uploadRequest : uploadsForThisJob) documentIds.add(uploadRequest.contentDocumentId);

        Map<Id, ContentVersion> versionsByDocumentId = new Map<Id, ContentVersion>();
        for (ContentVersion versionRecord : [
            SELECT ContentDocumentId, Title, FileExtension, ContentSize, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId IN :documentIds AND IsLatest = true
        ]) {
            versionsByDocumentId.put(versionRecord.ContentDocumentId, versionRecord);
        }

        for (UploadRequest uploadRequest : uploadsForThisJob) {
            ContentVersion versionRecord = versionsByDocumentId.get(uploadRequest.contentDocumentId);
            if (!isValidForUpload(versionRecord, uploadRequest)) continue;

            String fileName = versionRecord.Title +
                (String.isNotBlank(versionRecord.FileExtension) ? '.' + versionRecord.FileExtension : '');
            uploadWithRetry(config.Drive_Id__c, uploadRequest.folderItemId, fileName,
                versionRecord.VersionData, uploadRequest.contentDocumentId);
        }

        if (!remainingUploads.isEmpty()) System.enqueueJob(new SharePointUploadJob(remainingUploads));
    }

    private List<UploadRequest> buildUploadRequests(SharePoint_Config__mdt config) {
        if (documentToEntityIds.isEmpty()) return new List<UploadRequest>();

        Set<Id> directAccountIds = new Set<Id>();
        Set<Id> opportunityIds = new Set<Id>();
        Set<Id> contractIds = new Set<Id>();
        for (Set<Id> entityIds : documentToEntityIds.values()) {
            for (Id entityId : entityIds) {
                if (entityId.getSObjectType() == Account.SObjectType) directAccountIds.add(entityId);
                else if (entityId.getSObjectType() == Opportunity.SObjectType) opportunityIds.add(entityId);
                else if (entityId.getSObjectType() == Contract.SObjectType) contractIds.add(entityId);
            }
        }

        Map<Id, Opportunity> opportunitiesById = opportunityIds.isEmpty()
            ? new Map<Id, Opportunity>()
            : new Map<Id, Opportunity>([SELECT Id, AccountId FROM Opportunity WHERE Id IN :opportunityIds]);
        Map<Id, Contract> contractsById = contractIds.isEmpty()
            ? new Map<Id, Contract>()
            : new Map<Id, Contract>([
                SELECT Id, AccountId, Type_of_Contract__c, Status
                FROM Contract WHERE Id IN :contractIds
            ]);

        Set<Id> allAccountIds = new Set<Id>(directAccountIds);
        for (Opportunity opportunityRecord : opportunitiesById.values()) {
            if (opportunityRecord.AccountId != null) allAccountIds.add(opportunityRecord.AccountId);
        }
        for (Contract contractRecord : contractsById.values()) {
            if (contractRecord.AccountId != null) allAccountIds.add(contractRecord.AccountId);
        }

        Map<Id, Account> accountsById = allAccountIds.isEmpty()
            ? new Map<Id, Account>()
            : new Map<Id, Account>([
                SELECT Id, SharePoint_Folder_Id__c, SharePoint_Contract_Folder_Id__c,
                       SharePoint_Opportunities_Folder_Id__c
                FROM Account WHERE Id IN :allAccountIds
            ]);

        Map<Id, Set<String>> foldersByDocumentId = new Map<Id, Set<String>>();
        for (Id documentId : documentToEntityIds.keySet()) {
            for (Id entityId : documentToEntityIds.get(documentId)) {
                if (entityId.getSObjectType() == Account.SObjectType) {
                    Account accountRecord = accountsById.get(entityId);
                    addFolder(foldersByDocumentId, documentId,
                        accountRecord == null ? null : accountRecord.SharePoint_Folder_Id__c);
                } else if (entityId.getSObjectType() == Opportunity.SObjectType) {
                    Opportunity opportunityRecord = opportunitiesById.get(entityId);
                    Account accountRecord = opportunityRecord == null ? null : accountsById.get(opportunityRecord.AccountId);
                    addFolder(foldersByDocumentId, documentId,
                        accountRecord == null ? null : accountRecord.SharePoint_Opportunities_Folder_Id__c);
                } else if (entityId.getSObjectType() == Contract.SObjectType) {
                    Contract contractRecord = contractsById.get(entityId);
                    Account accountRecord = contractRecord == null ? null : accountsById.get(contractRecord.AccountId);
                    addFolder(foldersByDocumentId, documentId,
                        accountRecord == null ? null : accountRecord.SharePoint_Contract_Folder_Id__c);
                    addFolder(foldersByDocumentId, documentId, getCentralContractFolderId(config, contractRecord));
                }
            }
        }

        List<UploadRequest> result = new List<UploadRequest>();
        for (Id documentId : foldersByDocumentId.keySet()) {
            for (String folderItemId : foldersByDocumentId.get(documentId)) {
                result.add(new UploadRequest(documentId, folderItemId));
            }
        }
        return result;
    }

    private static void addFolder(Map<Id, Set<String>> foldersByDocumentId, Id documentId, String folderItemId) {
        if (String.isBlank(folderItemId)) return;
        if (!foldersByDocumentId.containsKey(documentId)) foldersByDocumentId.put(documentId, new Set<String>());
        foldersByDocumentId.get(documentId).add(folderItemId);
    }

    private static String getCentralContractFolderId(SharePoint_Config__mdt config, Contract contractRecord) {
        if (contractRecord == null) return null;
        String folderName = SharePointFolderService.resolveContractFolderName(
            contractRecord.Type_of_Contract__c, contractRecord.Status
        );
        if (folderName == 'CDA') return config.CDA_Item_ID__c;
        if (folderName == 'LOI') return config.LOI_Item_ID__c;
        if (folderName == 'MSA') return config.MSA_Item_ID__c;
        if (folderName == 'CSA') return config.CSA_Item_ID__c;
        if (folderName == 'QAA') return config.QAA_Item_ID__c;
        if (folderName == 'Executive Review') return config.Executive_Review_Item_ID__c;
        if (folderName == 'Client Review') return config.Client_Review_Item_ID__c;
        if (folderName == 'Internal Review') return config.Internal_Review_Item_ID__c;
        return config.Misc_Item_ID__c;
    }

    private static Boolean isValidForUpload(ContentVersion versionRecord, UploadRequest uploadRequest) {
        if (versionRecord == null || versionRecord.VersionData == null) {
            logSkip(uploadRequest, 'the latest file version is unavailable.');
            return false;
        }
        if (versionRecord.ContentSize > MAX_FILE_SIZE_BYTES) {
            logSkip(uploadRequest, 'the file exceeds the 50 MB limit.');
            return false;
        }
        String extension = String.isBlank(versionRecord.FileExtension) ? '' : versionRecord.FileExtension.toLowerCase();
        if (RESTRICTED_FILE_EXTENSIONS.contains(extension)) {
            logSkip(uploadRequest, 'the file type ' + extension + ' is not allowed.');
            return false;
        }
        return true;
    }

    private static void logSkip(UploadRequest uploadRequest, String reason) {
        System.debug(LoggingLevel.WARN, 'SharePoint upload skipped for ContentDocument ' +
            uploadRequest.contentDocumentId + ', folder ' + uploadRequest.folderItemId + ': ' + reason);
    }

    private static void uploadWithRetry(String driveId, String folderItemId, String fileName,
        Blob fileData, Id contentDocumentId) {
        for (Integer attempt = 1; attempt <= MAX_UPLOAD_ATTEMPTS; attempt++) {
            try {
                SharePointGraphClient.uploadFile(driveId, folderItemId, fileName, fileData);
                return;
            } catch (Exception exceptionRecord) {
                if (attempt == MAX_UPLOAD_ATTEMPTS) {
                    System.debug(LoggingLevel.ERROR, 'SharePoint upload failed after ' +
                        MAX_UPLOAD_ATTEMPTS + ' attempts for ContentDocument ' + contentDocumentId +
                        ', folder ' + folderItemId + ': ' + exceptionRecord.getMessage());
                }
            }
        }
    }

    private class UploadRequest {
        private Id contentDocumentId;
        private String folderItemId;

        private UploadRequest(Id contentDocumentId, String folderItemId) {
            this.contentDocumentId = contentDocumentId;
            this.folderItemId = folderItemId;
        }
    }
}
