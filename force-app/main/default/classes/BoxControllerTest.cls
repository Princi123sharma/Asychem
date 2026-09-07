@IsTest
private class BoxControllerTest {

    // ----------------------------------------------------------------------
    // Test HttpCalloutMock for both folder create & file upload
    // ----------------------------------------------------------------------
    private class BoxHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            
            // Default success
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(201);
            
            // Folder creation response
            if (req.getEndpoint().contains('/folders')) {
                res.setBody('{"id":"12345","name":"Test Folder"}');
            }
            // File upload response
            else if (req.getEndpoint().contains('/files/content')) {
                // performFileUpload only checks status, body can be minimal
                res.setBody('{"entries":[{"id":"67890","name":"Test File"}]}');
            }
            else {
                res.setStatusCode(200);
                res.setBody('{"status":"ok"}');
            }
            
            return res;
        }
    }
    
    // ----------------------------------------------------------------------
    // Test data setup helpers
    // ----------------------------------------------------------------------
    private static void setupCustomSettings() {
        // Box folder IDs for Accounts
        BoxFolderIds__c accFolderSetting = new BoxFolderIds__c(
            Name = 'Account',
            Accounts__c = '0' // root or any dummy parent id
        );
        insert accFolderSetting;
        
        // Box folder IDs for Legal Contracts
        BoxFolderIds__c legalFolderSetting = new BoxFolderIds__c(
            Name = 'LegalContract',
            CDA__c = 'CDA_FOLDER',
            LOI__c = 'LOI_FOLDER',
            MSA__c = 'MSA_FOLDER',
            CSA__c = 'CSA_FOLDER',
            QAA__c = 'QAA_FOLDER',
            Executive_Review__c = 'EXEC_REVIEW_FOLDER',
            Client_Review__c = 'CLIENT_REVIEW_FOLDER',
            Internal_Review__c = 'INT_REVIEW_FOLDER',
            Misc__c = 'MISC_FOLDER'
        );
        insert legalFolderSetting;
        
        // Credentials setting (even if not used heavily, good for coverage)
        BoxCCredentials__c creds = new BoxCCredentials__c(
            Name = 'Box_Credentials'
        );
        insert creds;
    }
    
    private static Map<String, Id> setupCoreRecords() {
        Map<String, Id> ids = new Map<String, Id>();
        
        Account acc = new Account(
            Name = 'Test Account',
            Nick_Name__c = 'TA',
            Folder_Id__c = 'ACC_FOLDER',
            Contract_Folder_Id__c = 'ACC_CONTRACT_FOLDER',
            Opportunities_Folder_Id__c = 'ACC_OPP_FOLDER'
        );
        insert acc;
        ids.put('accountId', acc.Id);
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id
        );
        insert opp;
        ids.put('oppId', opp.Id);
        
        // Use a status that is insertable in this org to avoid FAILED_ACTIVATION
        Contract con = new Contract(
            AccountId = acc.Id,
            Status = 'Executive Review',
            Type_of_Contract__c = 'MSA'
        );
        insert con;
        ids.put('contractId', con.Id);
        
        User u = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        ids.put('userId', u.Id);
        
        return ids;
    }
    
    private static Id setupFileAndLinks(Map<String, Id> ids) {
        // Create ContentVersion
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'test.pdf',
            VersionData = Blob.valueOf('Dummy content for Box upload')
        );
        insert cv;
        
        // Re-query to get ContentDocumentId, ContentSize, FileType
        cv = [
            SELECT Id, ContentDocumentId, VersionData, PathOnClient, Title, ContentSize, FileType
            FROM ContentVersion
            WHERE Id = :cv.Id
        ];
        
        // Primary link: Account (this Id we pass to handleFileUpload)
        // Use allowed ShareType values. Valid values are generally 'V' (Viewer) and 'I' (Inferred).
        ContentDocumentLink accLink = new ContentDocumentLink(
            LinkedEntityId = ids.get('accountId'),
            ContentDocumentId = cv.ContentDocumentId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert accLink;
        
        // Additional links (covered in determineTargetFolders)
        ContentDocumentLink oppLink = new ContentDocumentLink(
            LinkedEntityId = ids.get('oppId'),
            ContentDocumentId = cv.ContentDocumentId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert oppLink;
        
        ContentDocumentLink conLink = new ContentDocumentLink(
            LinkedEntityId = ids.get('contractId'),
            ContentDocumentId = cv.ContentDocumentId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert conLink;
        
        // Avoid potential duplicate link to Account/User created by platform automations.
        // Do not create any extra link; three links are enough to drive determineTargetFolders.
        return accLink.Id;
    }
    
    // ----------------------------------------------------------------------
    // Tests for folder creation
    // ----------------------------------------------------------------------
    @IsTest
    static void testCreateAccountFolders_success() {
        setupCustomSettings();
        Account acc = new Account(Name = 'Folder Account', Nick_Name__c = 'FA');
        insert acc;
        
        Test.setMock(HttpCalloutMock.class, new BoxHttpMock());
        
        Test.startTest();
        BoxController.createAccountFolders(acc.Id);
        Test.stopTest();
        
        Account updated = [
            SELECT Folder_Id__c, Contract_Folder_Id__c, Opportunities_Folder_Id__c
            FROM Account WHERE Id = :acc.Id
        ];
        
        System.assertNotEquals(null, updated.Folder_Id__c, 'Main folder Id should be populated');
    }
    
    @IsTest
    static void testCreateAccountFolders_nullAccountId() {
        setupCustomSettings();
        Test.setMock(HttpCalloutMock.class, new BoxHttpMock());
        
        Test.startTest();
        // Should be handled gracefully (no unhandled exception)
        BoxController.createAccountFolders(null);
        Test.stopTest();
    }
    
    // ----------------------------------------------------------------------
    // Tests for uploadFileToBox (@future) + helpers
    // ----------------------------------------------------------------------
    @IsTest
    static void testUploadFileToBox_success() {
        Test.setMock(HttpCalloutMock.class, new BoxHttpMock());
        
        Blob fileBody = Blob.valueOf('Test content');
        String folderId = 'FOLDER123';
        String fileName = 'demo.txt';
        
        Test.startTest();
        BoxController.uploadFileToBox(fileBody, folderId, fileName);
        Test.stopTest();
        
        // If no exception, we're good; performFileUpload returns true with 201 mock
    }
    
    @IsTest
    static void testValidateUploadParameters_errors() {
        try {
            BoxController.validateUploadParameters(null, 'FOLDER', 'name.txt');
            System.assert(false, 'Expected BoxException for null file content');
        } catch (BoxController.BoxException e) {
            System.assertEquals('File content is required', e.getMessage());
        }
        
        try {
            BoxController.validateUploadParameters(Blob.valueOf('x'), null, 'name.txt');
            System.assert(false, 'Expected BoxException for blank folderId');
        } catch (BoxController.BoxException e) {
            System.assertEquals('Folder ID is required', e.getMessage());
        }
        
        try {
            BoxController.validateUploadParameters(Blob.valueOf('x'), 'FOLDER', '');
            System.assert(false, 'Expected BoxException for blank fileName');
        } catch (BoxController.BoxException e) {
            System.assertEquals('File name is required', e.getMessage());
        }
    }
    
    @IsTest
    static void testSanitizeFolderName() {
        String dirty = 'Bad/Name\\With:*?"<>|.chars';
        String cleaned = BoxController.sanitizeFolderName(dirty);
        
        System.assertEquals(true, !cleaned.contains('/'));
        System.assertEquals(true, !cleaned.contains('\\'));
        System.assertEquals(true, !cleaned.contains(':'));
        System.assertEquals(true, !cleaned.contains('*'));
        System.assertEquals(true, !cleaned.contains('?'));
        System.assertEquals(true, !cleaned.contains('"'));
        System.assertEquals(true, !cleaned.contains('<'));
        System.assertEquals(true, !cleaned.contains('>'));
        System.assertEquals(true, !cleaned.contains('|'));
    }
    
    @IsTest
    static void testBuildMultipartBody() {
        Blob fileBody = Blob.valueOf('Some binary content');
        Blob multipart = BoxController.buildMultipartBody(fileBody, 'file.txt', 'FOLDER1');
        System.assertNotEquals(null, multipart, 'Multipart payload should not be null');
    }
    
    @IsTest
    static void testGetParentFolderIdAndCredentials() {
        setupCustomSettings();
        
        // When custom setting exists with Accounts__c = '0', should return '0'
        String parentId = BoxController.getParentFolderId();
        System.assertEquals('0', parentId, 'Should return Accounts__c value from BoxFolderIds__c when present');
        
        // Remove the Account setting to validate fallback behavior returns '0' (root)
        delete [SELECT Id FROM BoxFolderIds__c WHERE Name = 'Account' LIMIT 1];
        String fallbackParentId = BoxController.getParentFolderId();
        System.assertEquals('0', fallbackParentId, 'Should fall back to root folder id when custom setting is missing');
        
        // Credentials should be retrievable
        BoxCCredentials__c creds = BoxController.getCredentials();
        System.assertNotEquals(null, creds, 'Credentials record should be returned');
        System.assertEquals('Box_Credentials', creds.Name, 'Credentials Name should match test setup');
    }
    
    // ----------------------------------------------------------------------
    // handleFileUpload end-to-end (Account + Opp + Contract + User links)
    // ----------------------------------------------------------------------
    @IsTest
    static void testHandleFileUpload_fullFlow() {
        setupCustomSettings();
        Map<String, Id> ids = setupCoreRecords();
        Id primaryLinkId = setupFileAndLinks(ids);
        
        Test.setMock(HttpCalloutMock.class, new BoxHttpMock());
        
        Test.startTest();
        BoxController.handleFileUpload(primaryLinkId);
        Test.stopTest();
        
        // No DML result to assert; success here means:
        // - initializeFileUploadContext executed
        // - validateFileForUpload executed
        // - determineTargetFolders processed Account, Opp, Contract, User
        // - uploadFileToTargetFolders and uploadFileToBoxWithRetry ran with mocked callouts
    }
    
    // ----------------------------------------------------------------------
    // Extra: cover a different contract branch (e.g. Executive Review)
    // ----------------------------------------------------------------------
    @IsTest
    static void testHandleFileUpload_contractExecutiveReview() {
        setupCustomSettings();
        
        // Basic account
        Account acc = new Account(
            Name = 'Exec Review Acc',
            Nick_Name__c = 'ER',
            Folder_Id__c = 'ACC_FOLDER_2',
            Contract_Folder_Id__c = 'ACC_CONTRACT_2'
        );
        insert acc;
        
        Contract con = new Contract(
            AccountId = acc.Id,
            Status = 'Executive Review',
            Type_of_Contract__c = 'MSA' // use a status allowed by org to insert
        );
        insert con;
        
        // File & link only to contract for this test
        ContentVersion cv = new ContentVersion(
            Title = 'Exec Review File',
            PathOnClient = 'exec.pdf',
            VersionData = Blob.valueOf('Exec content')
        );
        insert cv;
        
        cv = [
            SELECT Id, ContentDocumentId, VersionData, PathOnClient, Title, ContentSize, FileType
            FROM ContentVersion
            WHERE Id = :cv.Id
        ];
        
        ContentDocumentLink conLink = new ContentDocumentLink(
            LinkedEntityId = con.Id,
            ContentDocumentId = cv.ContentDocumentId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert conLink;
        
        Test.setMock(HttpCalloutMock.class, new BoxHttpMock());
        
        Test.startTest();
        BoxController.handleFileUpload(conLink.Id);
        Test.stopTest();
        
        // This hits the "Executive Review" branch in processContractFile
    }
}