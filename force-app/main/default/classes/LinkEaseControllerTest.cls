@IsTest
private class LinkEaseControllerTest {
    private static Set<String> contractUploadTargets;
    private class UploadMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            System.assertEquals('PUT', request.getMethod());
            System.assert(request.getEndpoint().contains('/items/account-folder:/linkease.txt:/content'));
            System.assert(
                request.getEndpoint().contains('@microsoft.graph.conflictBehavior=rename'),
                'LinkEase must retain same-name files by creating a renamed copy.'
            );
            HttpResponse response = new HttpResponse();
            response.setStatusCode(201);
            response.setBody(
                '{"id":"sharepoint-item-id","name":"linkease.txt","file":{},' +
                '"lastModifiedBy":{"application":{"displayName":"SharePoint App"}}}'
            );
            return response;
        }
    }

    private class UploadFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(500);
            response.setBody('Upload failed');
            return response;
        }
    }

    private class ContractFolderUploadMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            System.assertEquals('PUT', request.getMethod());
            System.assert(request.getEndpoint().contains('@microsoft.graph.conflictBehavior=rename'));
            if (request.getEndpoint().contains('/items/account-contract-folder:/contract.txt:/content')) {
                contractUploadTargets.add('account-contract-folder');
            } else if (request.getEndpoint().contains('/items/central-cda-folder:/contract.txt:/content')) {
                contractUploadTargets.add('central-cda-folder');
            } else {
                System.assert(false, 'Unexpected Contract upload target: ' + request.getEndpoint());
            }

            HttpResponse response = new HttpResponse();
            response.setStatusCode(201);
            response.setBody(
                '{"id":"sharepoint-item-id","name":"contract.txt","file":{},' +
                '"lastModifiedBy":{"application":{"displayName":"SharePoint App"}}}'
            );
            return response;
        }
    }

    private class AccountFolderIdMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            System.assertEquals('PUT', request.getMethod());
            System.assert(
                request.getEndpoint().contains('/items/stale-account-folder:/resolved.txt:/content'),
                'The upload must use the SharePoint folder ID saved on the Account.'
            );
            response.setStatusCode(201);
            response.setBody('{"id":"resolved-file-id","name":"resolved.txt"}');
            return response;
        }
    }

    private class UploadSessionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            System.assertEquals('POST', request.getMethod());
            System.assert(
                request.getEndpoint().contains('/items/account-folder:/large-linkease.pdf:/createUploadSession')
            );
            System.assert(
                request.getBody().contains('"@microsoft.graph.conflictBehavior":"rename"'),
                'Chunked LinkEase uploads must retain same-name files by creating a renamed copy.'
            );
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"uploadUrl":"https://upload.example.test/session"}');
            return response;
        }
    }

    private class ChunkUploadMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            System.assertEquals('PUT', request.getMethod());
            System.assertEquals('application/octet-stream', request.getHeader('Content-Type'));
            System.assertEquals('5', request.getHeader('Content-Length'));
            System.assertEquals('bytes 0-4/5', request.getHeader('Content-Range'));
            HttpResponse response = new HttpResponse();
            response.setStatusCode(201);
            response.setBody('{"id":"completed-file"}');
            return response;
        }
    }

    private class ChunkFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(503);
            response.setBody('SharePoint temporarily unavailable');
            return response;
        }
    }

    private class ListFilesMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            System.assertEquals('GET', request.getMethod());
            System.assert(request.getEndpoint().contains('/items/account-folder/children'));
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"value":[{"id":"file-id","name":"existing.pdf","size":1024,"webUrl":"https://example.test/file","file":{}},{"id":"folder-id","name":"Subfolder","folder":{}}]}');
            return response;
        }
    }

    private class FolderTreeMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            if (request.getEndpoint().contains('?$select=webUrl')) {
                HttpResponse itemResponse = new HttpResponse(); itemResponse.setStatusCode(200); itemResponse.setBody('{"webUrl":"https://example.test/account"}'); return itemResponse;
            }
            System.assertEquals('GET', request.getMethod());
            System.assert(request.getEndpoint().contains('/items/account-folder/children'));
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody(
                '{"value":[' +
                '{"id":"contracts-folder","name":"Contracts","folder":{},' +
                '"lastModifiedDateTime":"2026-09-11T12:54:00Z",' +
                '"lastModifiedBy":{"application":{"displayName":"SharePoint App"}}},' +
                '{"id":"opportunities-folder","name":"Opportunities","folder":{},' +
                '"lastModifiedDateTime":"2026-09-11T12:54:00Z",' +
                '"lastModifiedBy":{"application":{"displayName":"SharePoint App"}}},' +
                '{"id":"account-file","name":"account-site (11).csv","size":1024,"file":{},' +
                '"lastModifiedDateTime":"2026-09-11T12:54:00Z",' +
                '"lastModifiedBy":{"application":{"displayName":"SharePoint App"}}}' +
                ']}'
            );
            return response;
        }
    }

    private class NestedFolderMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            if (request.getEndpoint().contains('?$select=webUrl')) {
                HttpResponse itemResponse = new HttpResponse();
                itemResponse.setStatusCode(200);
                itemResponse.setBody('{"webUrl":"https://example.test/contracts"}');
                return itemResponse;
            }
            if (request.getEndpoint().contains('?$select=parentReference')) {
                HttpResponse parentResponse = new HttpResponse();
                parentResponse.setStatusCode(200);
                parentResponse.setBody('{"parentReference":{"id":"account-folder"}}');
                return parentResponse;
            }
            System.assertEquals('GET', request.getMethod());
            System.assert(request.getEndpoint().contains('/items/contracts-folder/children'));
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody(
                '{"value":[{"id":"contract-file","name":"contract.pdf","size":2048,"file":{},' +
                '"lastModifiedBy":{"user":{"displayName":"Aryan Chopra"}}}]}'
            );
            return response;
        }
    }

    @IsTest
    static void uploadsAnAccountFileWithoutCreatingSalesforceFiles() {
        Account accountRecord = new Account(
            Name = 'LinkEase Test',
            Nick_Name__c = 'LinkEase Test',
            SharePoint_Folder_Id__c = 'account-folder'
        );
        TriggerControlHelper.isBatchRunning = true; insert accountRecord; TriggerControlHelper.isBatchRunning = false;

        LinkEaseController.configOverride = new SharePoint_Config__mdt(Drive_Id__c = 'drive-id');
        Test.setMock(HttpCalloutMock.class, new UploadMock());

        Test.startTest();
        LinkEaseController.UploadResult result = LinkEaseController.uploadFile(
            accountRecord.Id,
            'linkease.txt',
            EncodingUtil.base64Encode(Blob.valueOf('direct to SharePoint')), null
        );
        Test.stopTest();

        System.assertEquals('sharepoint-item-id', result.driveItemId);
        System.assertEquals('account-folder', result.folderItemId);
        System.assertEquals(0, [SELECT Count() FROM ContentDocument]);
    }

    @IsTest
    static void createsAReplaceSessionForLargeLinkEaseUploads() {
        Account accountRecord = new Account(
            Name = 'Large Upload Parent',
            Nick_Name__c = 'Large Upload Parent',
            SharePoint_Folder_Id__c = 'account-folder'
        );
        TriggerControlHelper.isBatchRunning = true; insert accountRecord; TriggerControlHelper.isBatchRunning = false;

        LinkEaseController.configOverride = new SharePoint_Config__mdt(Drive_Id__c = 'drive-id');
        Test.setMock(HttpCalloutMock.class, new UploadSessionMock());

        Test.startTest();
        LinkEaseController.UploadSessionResult result = LinkEaseController.createUploadSession(
            accountRecord.Id, 'large-linkease.pdf', null, 5 * 1024 * 1024
        );
        Test.stopTest();

        System.assertEquals(1, result.sessionIds.size());
        SharePoint_Upload_Session__c sessionRecord = [
            SELECT Status__c, Total_Size__c FROM SharePoint_Upload_Session__c WHERE Id = :result.sessionIds[0]
        ];
        System.assertEquals('Active', sessionRecord.Status__c);
        System.assertEquals(5 * 1024 * 1024, sessionRecord.Total_Size__c);
    }

    @IsTest
    static void completesAFinalBinaryChunkAndMarksItsSessionComplete() {
        SharePoint_Upload_Session__c sessionRecord = new SharePoint_Upload_Session__c(
            Upload_Url__c = 'https://upload.example.test/session', Total_Size__c = 5,
            Next_Byte__c = 0, Status__c = 'Active', Expires_At__c = System.now().addHours(1)
        );
        insert sessionRecord;
        Test.setMock(HttpCalloutMock.class, new ChunkUploadMock());

        Test.startTest();
        LinkEaseController.UploadChunkResult result = LinkEaseController.uploadChunk(sessionRecord.Id, 'Ynl0ZXM=', 0, 5);
        Test.stopTest();

        System.assertEquals(true, result.success);
        sessionRecord = [SELECT Next_Byte__c, Status__c FROM SharePoint_Upload_Session__c WHERE Id = :sessionRecord.Id];
        System.assertEquals(5, sessionRecord.Next_Byte__c);
        System.assertEquals('Completed', sessionRecord.Status__c);
    }

    @IsTest
    static void marksTheSessionFailedWhenSharePointRejectsAChunk() {
        SharePoint_Upload_Session__c sessionRecord = new SharePoint_Upload_Session__c(
            Upload_Url__c = 'https://upload.example.test/session', Total_Size__c = 5,
            Next_Byte__c = 0, Status__c = 'Active', Expires_At__c = System.now().addHours(1)
        );
        insert sessionRecord;
        Test.setMock(HttpCalloutMock.class, new ChunkFailureMock());

        LinkEaseController.UploadChunkResult result = LinkEaseController.uploadChunk(
            sessionRecord.Id, 'Ynl0ZXM=', 0, 5
        );
        System.assertEquals(false, result.success);
        System.assert(result.errorMessage.contains('upload chunk failed'));
        sessionRecord = [SELECT Status__c FROM SharePoint_Upload_Session__c WHERE Id = :sessionRecord.Id];
        System.assertEquals('Failed', sessionRecord.Status__c);
    }

    @IsTest
    static void uploadsToTheFolderSavedOnTheAccount() {
        Account accountRecord = new Account(
            Name = 'Folder Match',
            Nick_Name__c = 'Folder Match',
            SharePoint_Folder_Id__c = 'stale-account-folder'
        );
        TriggerControlHelper.isBatchRunning = true; insert accountRecord; TriggerControlHelper.isBatchRunning = false;

        LinkEaseController.configOverride = new SharePoint_Config__mdt(
            Drive_Id__c = 'drive-id',
            Accounts_Parent_Item_Id__c = 'accounts-parent'
        );
        Test.setMock(HttpCalloutMock.class, new AccountFolderIdMock());

        Test.startTest();
        LinkEaseController.UploadResult result = LinkEaseController.uploadFile(
            accountRecord.Id,
            'resolved.txt',
            // A user may be viewing Contracts, but Account-page uploads must
            // still go to the Account root.
            EncodingUtil.base64Encode(Blob.valueOf('correct destination')), 'contracts-folder'
        );
        Test.stopTest();

        System.assertEquals('stale-account-folder', result.folderItemId);
        System.assertEquals('resolved-file-id', result.driveItemId);
    }

    @IsTest
    static void uploadsContractFilesToAccountAndCentralCdaFolders() {
        Account accountRecord = new Account(
            Name = 'Contract Upload Parent',
            Nick_Name__c = 'Contract Upload Parent',
            SharePoint_Folder_Id__c = 'account-folder',
            SharePoint_Contract_Folder_Id__c = 'account-contract-folder'
        );
        TriggerControlHelper.isBatchRunning = true; insert accountRecord; TriggerControlHelper.isBatchRunning = false;
        Contract contractRecord = new Contract(
            AccountId = accountRecord.Id,
            StartDate = Date.today(),
            Status = 'Client Review',
            Type_of_Contract__c = '2-way CDA'
        );
        insert contractRecord;

        contractUploadTargets = new Set<String>();
        // Match production config: central IDs live on *Item_ID__c, not *Folder_Item_Id__c.
        LinkEaseController.configOverride = new SharePoint_Config__mdt(
            Drive_Id__c = 'drive-id',
            Client_Review_Item_ID__c = 'central-cda-folder'
        );
        Test.setMock(HttpCalloutMock.class, new ContractFolderUploadMock());

        Test.startTest();
        LinkEaseController.UploadResult result = LinkEaseController.uploadFile(
            // LinkEase passes the currently displayed Account Contracts folder.
            // A Contract upload must still add the central destination.
            contractRecord.Id, 'contract.txt', 'Y29udHJhY3Q=', 'account-contract-folder'
        );
        Test.stopTest();

        System.assertEquals(2, contractUploadTargets.size(),
            'Contract files must upload to the Account Contracts folder and the central type folder.');
        System.assert(contractUploadTargets.contains('account-contract-folder'));
        System.assert(contractUploadTargets.contains('central-cda-folder'));
        System.assertNotEquals(null, result.driveItemId);
    }

    @IsTest
    static void rejectsRestrictedFileTypes() {
        try {
            LinkEaseController.uploadFile(
                '001000000000000AAA', 'unsafe.exe', EncodingUtil.base64Encode(Blob.valueOf('file')), null
            );
            System.assert(false, 'Expected a restricted-file exception.');
        } catch (AuraHandledException exceptionRecord) {
            System.assert(exceptionRecord.getMessage().contains('not allowed'));
        }
    }

    @IsTest
    static void validatesRequiredDataBeforeTryingToUpload() {
        assertHandled(null, 'file.txt', EncodingUtil.base64Encode(Blob.valueOf('file')), 'record ID');
        assertHandled('001000000000000AAA', '', 'ZmlsZQ==', 'Select a file');
        assertHandled('001000000000000AAA', 'empty.txt', '', 'Select a file');
        assertHandled('001000000000000AAA', 'empty.txt', EncodingUtil.base64Encode(Blob.valueOf('')), 'Select a file');
        assertHandled('001000000000000AAA', 'broken.txt', 'not base64!', 'could not be read');
    }

    @IsTest
    static void reportsSharePointUploadFailures() {
        Account accountRecord = new Account(
            Name = 'Failure Parent', Nick_Name__c = 'Failure Parent',
            SharePoint_Folder_Id__c = 'account-folder'
        );
        TriggerControlHelper.isBatchRunning = true; insert accountRecord; TriggerControlHelper.isBatchRunning = false;
        LinkEaseController.configOverride = new SharePoint_Config__mdt(Drive_Id__c = 'drive-id');
        Test.setMock(HttpCalloutMock.class, new UploadFailureMock());
        assertHandled(accountRecord.Id, 'file.txt', 'ZmlsZQ==', 'SharePoint upload failed');
    }

    @IsTest
    static void listsOnlyFilesFromTheAccountSharePointFolder() {
        Account accountRecord = new Account(
            Name = 'List Parent', Nick_Name__c = 'List Parent',
            SharePoint_Folder_Id__c = 'account-folder'
        );
        TriggerControlHelper.isBatchRunning = true; insert accountRecord; TriggerControlHelper.isBatchRunning = false;
        LinkEaseController.configOverride = new SharePoint_Config__mdt(Drive_Id__c = 'drive-id');
        Test.setMock(HttpCalloutMock.class, new ListFilesMock());

        Test.startTest();
        List<LinkEaseController.SharePointFile> files = LinkEaseController.getFiles(accountRecord.Id);
        Test.stopTest();

        System.assertEquals(1, files.size());
        System.assertEquals('existing.pdf', files[0].name);
        System.assertEquals(1024, files[0].size);
    }

    @IsTest
    static void returnsTheAccountFolderContentsForTheLibraryView() {
        Account accountRecord = new Account(
            Name = 'Tree Parent', Nick_Name__c = 'Tree Parent',
            SharePoint_Folder_Id__c = 'account-folder'
        );
        TriggerControlHelper.isBatchRunning = true; insert accountRecord; TriggerControlHelper.isBatchRunning = false;
        LinkEaseController.configOverride = new SharePoint_Config__mdt(Drive_Id__c = 'drive-id');
        Test.setMock(HttpCalloutMock.class, new FolderTreeMock());

        Test.startTest();
        LinkEaseController.SharePointFolder tree = LinkEaseController.getFolderTree(accountRecord.Id);
        Test.stopTest();

        System.assertEquals('Tree Parent 2026', tree.name);
        System.assertEquals(3, tree.children.size());
        System.assertEquals('Contracts', tree.children[0].name);
        System.assertEquals(true, tree.children[0].isFolder);
        System.assertEquals('SharePoint App', tree.children[0].lastModifiedBy);
        System.assertEquals(0, tree.children[0].children.size());
        System.assertEquals('account-site (11).csv', tree.children[2].name);
        System.assertEquals(false, tree.children[2].isFolder);
    }

    @IsTest
    static void listsANestedFolderWhenOpenedFromTheLibrary() {
        Account accountRecord = new Account(
            Name = 'Nested Parent', Nick_Name__c = 'Nested Parent',
            SharePoint_Folder_Id__c = 'account-folder'
        );
        TriggerControlHelper.isBatchRunning = true; insert accountRecord; TriggerControlHelper.isBatchRunning = false;
        LinkEaseController.configOverride = new SharePoint_Config__mdt(Drive_Id__c = 'drive-id');
        Test.setMock(HttpCalloutMock.class, new NestedFolderMock());

        Test.startTest();
        LinkEaseController.SharePointFolder folder = LinkEaseController.getFolderContents(
            accountRecord.Id, 'contracts-folder'
        );
        Test.stopTest();

        System.assertEquals('contracts-folder', folder.id);
        System.assertEquals(1, folder.children.size());
        System.assertEquals('contract.pdf', folder.children[0].name);
        System.assertEquals('Aryan Chopra', folder.children[0].lastModifiedBy);
    }

    @IsTest
    static void requiresTheSpecificOpportunityFolder() {
        Account accountRecord = new Account(
            Name = 'Opportunity Parent', Nick_Name__c = 'Opportunity Parent',
            SharePoint_Folder_Id__c = 'account-folder'
        );
        TriggerControlHelper.isBatchRunning = true; insert accountRecord; TriggerControlHelper.isBatchRunning = false;
        Opportunity opportunityRecord = new Opportunity(
            Name = 'LinkEase Opportunity', AccountId = accountRecord.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert opportunityRecord;
        LinkEaseController.configOverride = new SharePoint_Config__mdt(Drive_Id__c = 'drive-id');
        assertHandled(opportunityRecord.Id, 'file.txt', 'ZmlsZQ==', 'No SharePoint folder');
    }

    private static void assertHandled(Id recordId, String fileName, String base64Data, String expectedMessage) {
        try {
            LinkEaseController.uploadFile(recordId, fileName, base64Data, null);
            System.assert(false, 'Expected an AuraHandledException.');
        } catch (AuraHandledException exceptionRecord) {
            System.assert(exceptionRecord.getMessage().contains(expectedMessage));
        }
    }
}
