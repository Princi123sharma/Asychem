/**
 * @description Controller for Box integration functionality
 * @author Salesforce Development Team
 * @version 1.0
 * @since 2024
 */
public with sharing class BoxController {
    
    // ========================================
    // CONSTANTS
    // ========================================
    
    @TestVisible private static final String FOLDER_NAMED_CREDENTIAL = 'callout:Box';
    @TestVisible private static final String UPLOAD_NAMED_CREDENTIAL = 'callout:Box_Upload';
    @TestVisible private static final String FOLDER_URL = FOLDER_NAMED_CREDENTIAL + '/2.0/folders';
    @TestVisible private static final String BOUNDARY = '----------------------------741e90d31eff';
    @TestVisible private static final Integer TIMEOUT_DURATION = 120000;
    @TestVisible private static final String BOX_CREDENTIALS_LABEL = 'Box_Credentials';
    @TestVisible public static final String SETTING_NAME = 'Box_Credentials';
    @TestVisible public static final String ACCESS_TOKEN_URL = 'https://api.box.com/oauth2/token';
    
    // ========================================
    // INNER CLASSES
    // ========================================
    
    /**
     * @description Wrapper class for folder creation response from Box API
     */
    public class FolderResult {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
    }
    
    /**
     * @description Generic API response wrapper for consistent return types
     */
    public class ApiResponse {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public Object data { get; set; }
        
        public ApiResponse(Boolean success, String message, Object data) {
            this.success = success;
            this.message = message;
            this.data = data;
        }
    }
    
    /**
     * @description Custom exception class for Box operations
     */
    public class BoxException extends Exception {}
    
    /**
     * @description Wrapper class for OAuth token response from Box API
     */
    public class OAuthResult {
        public String access_token { get; set; }
        public String refresh_token { get; set; }
        public Integer expires_in { get; set; }
        public String token_type { get; set; }
    }
    
    // ========================================
    // PUBLIC METHODS
    // ========================================
    /**
     * @description Creates folder structure for an account using BoxFolderIds__c custom setting
     * Creates main account folder and subfolders (Legal Contracts, Opportunities)
     * @param accountId Account ID to create folders for
     */
    @Future(callout = true)
    public static void createAccountFolders(Id accountId) {
        try {
            if (accountId == null) {
                throw new BoxException('Account ID is required');
            }
            
            Account account = getAccountData(accountId);
            
            // Get parent folder ID from BoxFolderIds__c custom setting
            String parentFolderId = getParentFolderIdFromCustomSetting();
            if (String.isBlank(parentFolderId)) {
                throw new BoxException('Parent folder ID not configured in BoxFolderIds__c custom setting');
            }
            
            // Create main account folder with sanitized name including current year
            DateTime currentYear = DateTime.now();
            String accountName = String.isNotBlank(account.Nick_Name__c) ? account.Nick_Name__c + ' ' + currentYear.year() : account.Name + ' ' + currentYear.year();
            String folderName = sanitizeFolderName(accountName);
            
            FolderResult mainFolder = createSingleFolder(folderName, parentFolderId);
            if (mainFolder == null) {
                throw new BoxException('Failed to create main folder for account: ' + accountName);
            }
            
            // Create subfolders within the main account folder
            FolderResult contractsFolder = createSingleFolder('Legal Contracts', mainFolder.id);
            FolderResult opportunitiesFolder = createSingleFolder('Opportunities', mainFolder.id);
            
            // Update account with the main folder ID
            updateAccountFolders(accountId, mainFolder.id, contractsFolder?.id, opportunitiesFolder?.id);
            
            System.debug(LoggingLevel.INFO, 'Successfully created folders for account: ' + accountName + 
                        ', Main Folder ID: ' + mainFolder.id);
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error creating account folders: ' + e.getMessage());
            handleFolderCreationError(accountId, e.getMessage());
        }
    }
    

    /**
     * @description Handles file upload automation when files are attached to records
     * Enhanced with improved error handling, validation, and performance optimizations
     * @param contentDocumentLinkId ContentDocumentLink ID for the uploaded file
     */
    @Future(callout = true)
    public static void handleFileUpload(Id contentDocumentLinkId) {
        FileUploadContext context = null;
        
        try {
            // Input validation
            if (contentDocumentLinkId == null) {
                throw new BoxException('ContentDocumentLink ID cannot be null');
            }
            
            // Initialize upload context with comprehensive data gathering
            context = initializeFileUploadContext(contentDocumentLinkId);
            
            if (context == null || context.contentVersion == null) {
                throw new BoxException('Failed to initialize file upload context or retrieve file content');
            }
            
            // Validate file before processing
            validateFileForUpload(context.contentVersion);
            
            // Process linked entities and determine target folders
            List<String> targetFolders = determineTargetFolders(context);
            
            if (targetFolders.isEmpty()) {
                System.debug(LoggingLevel.WARN, 'No valid target folders found for file: ' + context.contentVersion.Title);
                return;
            }
            
            // Upload file to all determined folders with retry mechanism
            uploadFileToTargetFolders(context.contentVersion, targetFolders);
            
            System.debug(LoggingLevel.INFO, 'Successfully processed file upload for: ' + context.contentVersion.Title);
            
        } catch (QueryException e) {
            handleFileUploadError('Database query failed', e, contentDocumentLinkId, context);
        } catch (BoxException e) {
            handleFileUploadError('Box API error', e, contentDocumentLinkId, context);
        } catch (CalloutException e) {
            handleFileUploadError('Callout failed', e, contentDocumentLinkId, context);
        } catch (Exception e) {
            handleFileUploadError('Unexpected error', e, contentDocumentLinkId, context);
        }
    }
    
    /**
     * @description Initializes file upload context with all necessary data
     * @param contentDocumentLinkId ContentDocumentLink ID
     * @return FileUploadContext with populated data
     */
    private static FileUploadContext initializeFileUploadContext(Id contentDocumentLinkId) {
        try {
            // Query the primary ContentDocumentLink
            ContentDocumentLink primaryLink = [
                SELECT Id, LinkedEntityId, ContentDocumentId, Visibility, ShareType,
                       ContentDocument.Title, ContentDocument.FileType, ContentDocument.ContentSize
                FROM ContentDocumentLink 
                WHERE Id = :contentDocumentLinkId 
                LIMIT 1
            ];
            
            // Query all links for this document to identify all linked entities
             List<ContentDocumentLink> allLinks = [
                 SELECT Id, LinkedEntityId, ContentDocumentId, Visibility, ShareType,
                        ContentDocument.Title, ContentDocument.FileType
                 FROM ContentDocumentLink 
                 WHERE ContentDocumentId = :primaryLink.ContentDocumentId
             ];
            
            // Query ContentVersion for file data
            ContentVersion cv = [
                SELECT VersionData, Id, PathOnClient, ContentDocumentId, Title, ContentSize, FileType
                FROM ContentVersion 
                WHERE ContentDocumentId = :primaryLink.ContentDocumentId 
                AND IsLatest = true
                LIMIT 1
            ];
            
            return new FileUploadContext(primaryLink, allLinks, cv);
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to initialize file upload context: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Validates file before upload
     * @param contentVersion ContentVersion to validate
     */
    private static void validateFileForUpload(ContentVersion contentVersion) {
        if (contentVersion.VersionData == null) {
            throw new BoxException('File content is empty or corrupted');
        }
        
        if (String.isBlank(contentVersion.PathOnClient)) {
            throw new BoxException('File name is missing');
        }
        
        // Check file size (Box has limits)
        if (contentVersion.ContentSize > 50 * 1024 * 1024) { // 50MB limit
            throw new BoxException('File size exceeds maximum allowed limit (50MB)');
        }
        
        // Check for potentially problematic file types
        Set<String> restrictedExtensions = new Set<String>{'exe', 'bat', 'cmd', 'scr'};
        String fileExtension = contentVersion.PathOnClient.substringAfterLast('.').toLowerCase();
        if (restrictedExtensions.contains(fileExtension)) {
            throw new BoxException('File type not allowed: ' + fileExtension);
        }
    }
    
    /**
     * @description Determines target folders based on linked entities
     * @param context FileUploadContext with entity information
     * @return List of target folder IDs
     */
    private static List<String> determineTargetFolders(FileUploadContext context) {
        List<String> targetFolders = new List<String>();
        Set<String> processedEntities = new Set<String>();
        
        for (ContentDocumentLink link : context.allLinks) {
            String entityId = link.LinkedEntityId;
            String entityType = entityId.substring(0, 3);
            
            // Avoid processing the same entity multiple times
            if (processedEntities.contains(entityId)) {
                continue;
            }
            processedEntities.add(entityId);
            
            try {
                switch on entityType {
                    when '001' { // Account
                        String accountFolder = processAccountFile(entityId);
                        if (String.isNotBlank(accountFolder)) {
                            targetFolders.add(accountFolder);
                        }
                    }
                    when '006' { // Opportunity
                        String opportunityFolder = processOpportunityFile(entityId);
                        if (String.isNotBlank(opportunityFolder)) {
                            targetFolders.add(opportunityFolder);
                        }
                    }
                    when '800' { // Contract
                        Map<String, String> contractFolders = processContractFile(entityId);
                        if (String.isNotBlank(contractFolders.get('accountFolder'))) {
                            targetFolders.add(contractFolders.get('accountFolder'));
                        }
                        if (String.isNotBlank(contractFolders.get('contractFolder'))) {
                            targetFolders.add(contractFolders.get('contractFolder'));
                        }
                    }
                    when '005' { // User
                        // Users don't have dedicated Box folders, skip silently
                        System.debug(LoggingLevel.DEBUG, 'Skipping User entity (no Box folder): ' + entityId);
                    }
                    when else {
                        System.debug(LoggingLevel.WARN, 'Unsupported entity type for Box upload: ' + entityType + ' (Entity ID: ' + entityId + ')');
                    }
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error processing entity ' + entityId + ': ' + e.getMessage());
                // Continue processing other entities
            }
        }
        
        // Remove duplicates while preserving order
        Set<String> uniqueFolders = new Set<String>();
        List<String> result = new List<String>();
        for (String folder : targetFolders) {
            if (!uniqueFolders.contains(folder)) {
                uniqueFolders.add(folder);
                result.add(folder);
            }
        }
        
        return result;
    }
    
    /**
     * @description Uploads file to multiple target folders with retry mechanism
     * @param contentVersion ContentVersion containing file data
     * @param targetFolders List of target folder IDs
     */
    private static void uploadFileToTargetFolders(ContentVersion contentVersion, List<String> targetFolders) {
        Integer successCount = 0;
        Integer failureCount = 0;
        List<String> failedFolders = new List<String>();
        
        for (String folderId : targetFolders) {
            try {
                Boolean uploadSuccess = uploadFileToBoxWithRetry(
                    contentVersion.VersionData, 
                    folderId, 
                    contentVersion.PathOnClient,
                    3 // Max retry attempts
                );
                
                if (uploadSuccess) {
                    successCount++;
                    System.debug(LoggingLevel.INFO, 'Successfully uploaded file to folder: ' + folderId);
                } else {
                    failureCount++;
                    failedFolders.add(folderId);
                    System.debug(LoggingLevel.ERROR, 'Failed to upload file to folder: ' + folderId);
                }
            } catch (Exception e) {
                failureCount++;
                failedFolders.add(folderId);
                System.debug(LoggingLevel.ERROR, 'Exception uploading to folder ' + folderId + ': ' + e.getMessage());
            }
        }
        
        // Log summary
        System.debug(LoggingLevel.INFO, 
            String.format('File upload summary - Success: {0}, Failed: {1}, Total: {2}', 
                new List<Object>{successCount, failureCount, targetFolders.size()})
        );
        
        if (!failedFolders.isEmpty()) {
            System.debug(LoggingLevel.WARN, 'Failed folder uploads: ' + String.join(failedFolders, ', '));
        }
    }
    
    /**
     * @description Uploads file to Box with retry mechanism
     * @param fileContent File content as Blob
     * @param folderId Target Box folder ID
     * @param fileName Name for the uploaded file
     * @param maxRetries Maximum number of retry attempts
     * @return Boolean indicating final upload success
     */
    private static Boolean uploadFileToBoxWithRetry(Blob fileContent, String folderId, String fileName, Integer maxRetries) {
        for (Integer attempt = 1; attempt <= maxRetries; attempt++) {
            try {
                validateUploadParameters(fileContent, folderId, fileName);
                Boolean success = performFileUpload(fileContent, folderId, fileName);
                
                if (success) {
                    if (attempt > 1) {
                        System.debug(LoggingLevel.INFO, 'Upload succeeded on attempt ' + attempt);
                    }
                    return true;
                }
                
                if (attempt < maxRetries) {
                    System.debug(LoggingLevel.WARN, 'Upload attempt ' + attempt + ' failed, retrying...');
                    // Add a small delay between retries (simulated with debug)
                    System.debug(LoggingLevel.INFO, 'Waiting before retry attempt ' + (attempt + 1));
                }
                
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Upload attempt ' + attempt + ' failed with exception: ' + e.getMessage());
                if (attempt >= maxRetries) {
                    throw e; // Re-throw on final attempt
                }
            }
        }
        
        return false;
    }
    
    /**
     * @description Centralized error handling for file upload operations
     * @param errorType Type of error that occurred
     * @param e Exception that was caught
     * @param contentDocumentLinkId Original ContentDocumentLink ID
     * @param context FileUploadContext (may be null)
     */
    private static void handleFileUploadError(String errorType, Exception e, Id contentDocumentLinkId, FileUploadContext context) {
        String fileName = (context != null && context.contentVersion != null) ? context.contentVersion.Title : 'Unknown';
        String errorMessage = String.format('{0} in handleFileUpload for file "{1}" (ContentDocumentLink: {2}): {3}', 
            new List<Object>{errorType, fileName, contentDocumentLinkId, e.getMessage()});
        
        System.debug(LoggingLevel.ERROR, errorMessage);
        System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
        
        // TODO: Consider implementing custom error logging or notification system
        // For example: create Error_Log__c records or send email notifications for critical failures
    }
    
    /**
     * @description Inner class to hold file upload context data
     */
    private class FileUploadContext {
        public ContentDocumentLink primaryLink { get; set; }
        public List<ContentDocumentLink> allLinks { get; set; }
        public ContentVersion contentVersion { get; set; }
        
        public FileUploadContext(ContentDocumentLink primaryLink, List<ContentDocumentLink> allLinks, ContentVersion contentVersion) {
            this.primaryLink = primaryLink;
            this.allLinks = allLinks;
            this.contentVersion = contentVersion;
        }
    }
    
    /**
     * @description Uploads a file to specified Box folder
     * @param fileContent File content as Blob
     * @param folderId Target Box folder ID
     * @param fileName Name for the uploaded file
     */
    @Future(callout = true)
    public static void uploadFileToBox(Blob fileContent, String folderId, String fileName) {
        try {
            validateUploadParameters(fileContent, folderId, fileName);
            
            Boolean uploadSuccess = performFileUpload(fileContent, folderId, fileName);
            
            if (!uploadSuccess) {
                throw new BoxException('File upload failed');
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error uploading file: ' + e.getMessage());
        }
    }
    
    // ========================================
    // PRIVATE HELPER METHODS - FILE PROCESSING
    // ========================================
    
    /**
     * @description Processes file upload for Account records
     * @param accId Account ID
     * @return Folder ID for file upload
     */
    private static String processAccountFile(String accId) {
        Account acc = [SELECT ID, Name, Folder_Id__c, Contract_Folder_Id__c, Opportunities_Folder_Id__c FROM Account WHERE id = :accId LIMIT 1];
        
        if(acc.Folder_Id__c == null) {
             createAccountFolders(Id.valueOf(accId));
         }
        
        Account acc2 = [SELECT ID, Name, Folder_Id__c, Contract_Folder_Id__c, Opportunities_Folder_Id__c FROM Account WHERE id = :accId LIMIT 1];
        return acc2.Folder_Id__c;
    }
    
    /**
     * @description Processes file upload for Opportunity records
     * @param oppId Opportunity ID
     * @return Folder ID for file upload
     */
    private static String processOpportunityFile(String oppId) {
        Opportunity op = [SELECT AccountId, Account.Folder_Id__c, Account.Opportunities_Folder_Id__c FROM opportunity WHERE id = :oppId LIMIT 1];
        
        if(op.AccountId != null) {
            if(op.Account.Folder_Id__c == null) {
                 createAccountFolders(op.AccountId);
             }
            Opportunity op2 = [SELECT AccountId, Account.Folder_Id__c, Account.Opportunities_Folder_Id__c FROM opportunity WHERE id = :oppId LIMIT 1];
            return op2.Account.Opportunities_Folder_Id__c;
        }
        return '';
    }
    
    /**
     * @description Processes file upload for Contract records
     * @param conId Contract ID
     * @return Map containing account folder and contract-specific folder IDs
     */
    private static Map<String, String> processContractFile(String conId) {
        Map<String, String> result = new Map<String, String>();
        
        Contract con = [SELECT Account.Contract_Folder_Id__c, AccountId, Account.Folder_Id__c, Type_of_Contract__c, Status FROM Contract WHERE id = :conId LIMIT 1];
        
        String folderId = '';
        String contractFolderId = '';
        
        if(con.AccountId != null) {
            if(con.Account.Folder_Id__c == null) {
                 createAccountFolders(con.AccountId);
             }
            Contract con2 = [SELECT Account.Contract_Folder_Id__c, AccountId, Account.Folder_Id__c, Type_of_Contract__c, Status FROM Contract WHERE id = :conId LIMIT 1];
            folderId = con2.Account.Contract_Folder_Id__c;
        }
        
        // Determine contract-specific folder based on status and type
        if(con.Status == 'Active' && (con.Type_of_Contract__c == '1-way CDA' || con.Type_of_Contract__c == '3-way CDA' || con.Type_of_Contract__c == '2-way CDA')) {
            contractFolderId = BoxFolderIds__c.getValues('LegalContract').CDA__c;
        }
        else if(con.Status == 'Active' && con.Type_of_Contract__c == 'LOI') {
            contractFolderId = BoxFolderIds__c.getValues('LegalContract').LOI__c;
        }
        else if(con.Status == 'Active' && con.Type_of_Contract__c == 'MSA') {
            contractFolderId = BoxFolderIds__c.getValues('LegalContract').MSA__c;
        }
        else if(con.Status == 'Active' && con.Type_of_Contract__c == 'CSA') {
            contractFolderId = BoxFolderIds__c.getValues('LegalContract').CSA__c;
        }
        else if(con.Status == 'Active' && con.Type_of_Contract__c == 'QAA') {
            contractFolderId = BoxFolderIds__c.getValues('LegalContract').QAA__c;
        }
        else if(con.Status == 'Executive Review' || con.Status == 'Client Review' || con.Status == 'Internal Review') {
            if(con.Status == 'Executive Review') {
                contractFolderId = BoxFolderIds__c.getValues('LegalContract').Executive_Review__c;
            }
            else if(con.Status == 'Client Review') {
                contractFolderId = BoxFolderIds__c.getValues('LegalContract').Client_Review__c;
            }
            else {
                contractFolderId = BoxFolderIds__c.getValues('LegalContract').Internal_Review__c;
            }
        }
        else if((con.Status == 'Terminated' || con.Status == 'Expired' || con.Status == 'Draft') && con.Type_of_Contract__c == 'Not Checked') {
            contractFolderId = BoxFolderIds__c.getValues('LegalContract').Misc__c;
        }
        
        result.put('accountFolder', folderId);
        result.put('contractFolder', contractFolderId);
        return result;
    }
    
    // ========================================
    // PRIVATE HELPER METHODS - CONFIGURATION
    // ========================================
    
    /**
     * @description Gets Box credentials from custom settings
     * @return BoxCCredentials__c record or null if not found
     */
    @TestVisible
    private static BoxCCredentials__c getCredentials() {
        try {
            return BoxCCredentials__c.getValues(BOX_CREDENTIALS_LABEL);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error retrieving credentials: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Gets account data required for folder creation
     * @param accountId Account ID to query
     * @return Account record with Name and Nick_Name__c fields
     */
    @TestVisible
    private static Account getAccountData(Id accountId) {
        return [SELECT Id, Name, Nick_Name__c FROM Account WHERE Id = :accountId LIMIT 1];
    }
    /**
     * @description Gets parent folder ID from BoxFolderIds__c custom setting
     * @return Parent folder ID for account folders or null if not configured
     */
    @TestVisible
    private static String getParentFolderIdFromCustomSetting() {
        try {
            BoxFolderIds__c folderIds = BoxFolderIds__c.getValues('Account');
            if (folderIds != null && String.isNotBlank(folderIds.Accounts__c)) {
                return folderIds.Accounts__c;
            }
            
            System.debug(LoggingLevel.WARN, 'BoxFolderIds__c custom setting not found for Account or Accounts__c field is empty');
            return null;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error retrieving parent folder ID from custom setting: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Gets parent folder ID with fallback to root folder
     * @return Parent folder ID or '0' (root) if custom setting not configured
     */
    @TestVisible
    private static String getParentFolderId() {
        String parentFolderId = getParentFolderIdFromCustomSetting();
        // Fallback to root folder if custom setting is not configured
        return String.isNotBlank(parentFolderId) ? parentFolderId : '0';
    }
    
    // ========================================
    // PRIVATE HELPER METHODS - HTTP OPERATIONS
    // ========================================
    
    /**
     * @description Sends HTTP request with comprehensive error handling
     * @param request HttpRequest to send
     * @return HttpResponse from the API call
     * @throws BoxException if HTTP status code indicates error
     */
    private static HttpResponse sendHttpRequest(HttpRequest request) {
        Http http = new Http();
        HttpResponse response = http.send(request);
        
        if (response.getStatusCode() >= 400) {
            throw new BoxException('HTTP Error ' + response.getStatusCode() + ': ' + response.getBody());
        }
        
        return response;
    }
    
    // ========================================
    // PRIVATE HELPER METHODS - FOLDER OPERATIONS
    // ========================================
    
    /**
     * @description Creates a single folder in Box using Named Credentials
     * @param folderName Name of the folder to create
     * @param parentId Parent folder ID where the new folder will be created
     * @return FolderResult with created folder details or null if failed
     */
    @TestVisible
    private static FolderResult createSingleFolder(String folderName, String parentId) {
        try {
            // Validate input parameters
            if (String.isBlank(folderName)) {
                throw new BoxException('Folder name cannot be blank');
            }
            if (String.isBlank(parentId)) {
                throw new BoxException('Parent ID cannot be blank');
            }
            
            Map<String, Object> folderData = new Map<String, Object>{
                'name' => folderName,
                'parent' => new Map<String, Object>{'id' => parentId}
            };
            
            String requestBody = JSON.serialize(folderData);
            System.debug(LoggingLevel.INFO, 'Creating folder with name: ' + folderName + ', parent: ' + parentId);
            System.debug(LoggingLevel.INFO, 'Request body: ' + requestBody);
            System.debug(LoggingLevel.INFO, 'Endpoint: ' + FOLDER_URL);
            
            HttpRequest request = new HttpRequest();
            request.setEndpoint(FOLDER_URL);
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json');
            request.setHeader('Accept', 'application/json');
            request.setTimeout(TIMEOUT_DURATION);
            request.setBody(requestBody);
            
            HttpResponse response = sendHttpRequest(request);
            
            System.debug(LoggingLevel.INFO, 'Response Status Code: ' + response.getStatusCode());
            System.debug(LoggingLevel.INFO, 'Response Body: ' + response.getBody());
            System.debug(LoggingLevel.INFO, 'Response Headers: ' + response.getHeaderKeys());
            
            if (response.getStatusCode() == 201) {
                FolderResult result = (FolderResult) JSON.deserialize(response.getBody(), FolderResult.class);
                System.debug(LoggingLevel.INFO, 'Successfully created folder with ID: ' + result.id);
                return result;
            } else {
                String errorMsg = 'Failed to create folder. Status: ' + response.getStatusCode() + ', Body: ' + response.getBody();
                System.debug(LoggingLevel.ERROR, errorMsg);
                throw new BoxException(errorMsg);
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error creating folder "' + folderName + '": ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            return null;
        }
    }
    
    /**
     * @description Updates account record with created folder IDs
     * @param accountId Account ID to update
     * @param mainFolderId Main account folder ID
     * @param contractsFolderId Contracts subfolder ID (currently not stored)
     * @param opportunitiesFolderId Opportunities subfolder ID (currently not stored)
     */
    @TestVisible
    private static void updateAccountFolders(Id accountId, String mainFolderId, String contractsFolderId, String opportunitiesFolderId) {
        Account acc = new Account(Id = accountId);
        acc.Folder_Id__c = mainFolderId;
        acc.Contract_Folder_Id__c = contractsFolderId;
        acc.Opportunities_Folder_Id__c = opportunitiesFolderId;
        update acc;
    }
    
    /**
     * @description Handles and logs folder creation errors
     * @param accountId Account ID where folder creation failed
     * @param errorMessage Error message to log
     */
    @TestVisible
    private static void handleFolderCreationError(Id accountId, String errorMessage) {
        // Log error or create error record for tracking
        System.debug(LoggingLevel.ERROR, 'Folder creation failed for account ' + accountId + ': ' + errorMessage);
    }
    
    // ========================================
    // PRIVATE HELPER METHODS - FILE UPLOAD OPERATIONS
    // ========================================
    
    /**
     * @description Validates file upload parameters
     * @param fileContent File content to validate
     * @param folderId Target folder ID to validate
     * @param fileName File name to validate
     * @throws BoxException if any parameter is invalid
     */
    @TestVisible
    private static void validateUploadParameters(Blob fileContent, String folderId, String fileName) {
        if (fileContent == null) {
            throw new BoxException('File content is required');
        }
        if (String.isBlank(folderId)) {
            throw new BoxException('Folder ID is required');
        }
        if (String.isBlank(fileName)) {
            throw new BoxException('File name is required');
        }
    }
    
    /**
     * @description Performs the actual file upload to Box using Named Credentials
     * @param fileContent File content as Blob
     * @param folderId Target Box folder ID
     * @param fileName Name for the uploaded file
     * @return Boolean indicating upload success
     */
    @TestVisible
    private static Boolean performFileUpload(Blob fileContent, String folderId, String fileName) {
        try {
            Blob bodyBlob = buildMultipartBody(fileContent, fileName, folderId);
            
            HttpRequest request = new HttpRequest();
            request.setEndpoint(UPLOAD_NAMED_CREDENTIAL + '/2.0/files/content');
            request.setMethod('POST');
            request.setHeader('Content-Type', 'multipart/form-data; boundary=' + BOUNDARY);
            request.setBodyAsBlob(bodyBlob);
            request.setTimeout(TIMEOUT_DURATION);
            
            HttpResponse response = sendHttpRequest(request);
            return response.getStatusCode() == 201;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Upload failed: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * @description Builds multipart/form-data body for Box file upload
     * Uses hex encoding for reliable binary concatenation - works for ALL file types
     * @param fileContent File content as Blob
     * @param fileName Name of the file
     * @param folderId Target folder ID
     * @return Blob containing properly formatted multipart body
     */
    @TestVisible
    private static Blob buildMultipartBody(Blob fileContent, String fileName, String folderId) {
        String boundary = BOUNDARY;
        
        // Create attributes JSON
        Map<String, Object> attributes = new Map<String, Object>{
            'name' => fileName,
            'parent' => new Map<String, Object>{'id' => folderId}
        };
        String attributesJson = JSON.serialize(attributes);
        
        // Build multipart form data parts
        String attributesField = '--' + boundary + '\r\n' +
            'Content-Disposition: form-data; name="attributes"\r\n\r\n' +
            attributesJson + '\r\n';
            
        String fileHeader = '--' + boundary + '\r\n' +
            'Content-Disposition: form-data; name="file"; filename="' + fileName + '"\r\n' +
            'Content-Type: application/octet-stream\r\n\r\n';
            
        String footer = '\r\n--' + boundary + '--\r\n';
        
        // Use hex encoding for reliable concatenation - no padding issues!
        String attributesHex = EncodingUtil.convertToHex(Blob.valueOf(attributesField));
        String headerHex = EncodingUtil.convertToHex(Blob.valueOf(fileHeader));
        String bodyHex = EncodingUtil.convertToHex(fileContent);
        String footerHex = EncodingUtil.convertToHex(Blob.valueOf(footer));
        
        // Concatenate hex strings and convert back to blob
        String completeHex = attributesHex + headerHex + bodyHex + footerHex;
        
        return EncodingUtil.convertFromHex(completeHex);
    }
    
    // ========================================
    // PRIVATE HELPER METHODS - UTILITY FUNCTIONS
    // ========================================
    
    /**
     * @description Sanitizes folder name by removing invalid characters
     * @param name Original folder name
     * @return Sanitized folder name safe for Box API
     */
    @TestVisible
    private static String sanitizeFolderName(String name) {
        if (String.isBlank(name)) {
            return 'Unnamed';
        }
        
        return name.trim()
            .replace('/', ' ')
            .replace('\\', ' ')
            .replace('.', ' ')
            .replace(':', ' ')
            .replace('*', ' ')
            .replace('?', ' ')
            .replace('"', ' ')
            .replace('<', ' ')
            .replace('>', ' ')
            .replace('|', ' ');
    }
    

}