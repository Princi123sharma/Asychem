@IsTest
private class LinkEaseControllerTest {
    private class UploadMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            System.assertEquals('PUT', request.getMethod());
            System.assert(request.getEndpoint().contains('/items/account-folder:/linkease.txt:/content'));
            HttpResponse response = new HttpResponse();
            response.setStatusCode(201);
            response.setBody('{"id":"sharepoint-item-id","name":"linkease.txt"}');
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
            System.assert(
                request.getEndpoint().contains('/items/account-contract-folder:/contract.txt:/content')
                    || request.getEndpoint().contains('/items/central-cda-folder:/contract.txt:/content'),
                'Unexpected Contract upload target: ' + request.getEndpoint()
            );

            HttpResponse response = new HttpResponse();
            response.setStatusCode(201);
            response.setBody('{"id":"sharepoint-item-id","name":"contract.txt"}');
            return response;
        }
    }

    private class AccountFolderResolutionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            if (request.getMethod() == 'GET') {
                System.assert(request.getEndpoint().contains('/items/accounts-parent/children'));
                response.setStatusCode(200);
                response.setBody(
                    '{"value":[{"id":"correct-account-folder","name":"Folder Match 2026","folder":{}}]}'
                );
                return response;
            }

            System.assertEquals('PUT', request.getMethod());
            System.assert(
                request.getEndpoint().contains('/items/correct-account-folder:/resolved.txt:/content'),
                'The upload must use the folder resolved from the configured Accounts parent.'
            );
            response.setStatusCode(201);
            response.setBody('{"id":"resolved-file-id","name":"resolved.txt"}');
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

    @IsTest
    static void uploadsAnAccountFileWithoutCreatingSalesforceFiles() {
        Account accountRecord = new Account(
            Name = 'LinkEase Test',
            Nick_Name__c = 'LinkEase Test',
            SharePoint_Folder_Id__c = 'account-folder'
        );
        insert accountRecord;

        LinkEaseController.configOverride = new SharePoint_Config__mdt(Drive_Id__c = 'drive-id');
        Test.setMock(HttpCalloutMock.class, new UploadMock());

        Test.startTest();
        LinkEaseController.UploadResult result = LinkEaseController.uploadFile(
            accountRecord.Id,
            'linkease.txt',
            EncodingUtil.base64Encode(Blob.valueOf('direct to SharePoint'))
        );
        Test.stopTest();

        System.assertEquals('sharepoint-item-id', result.driveItemId);
        System.assertEquals('account-folder', result.folderItemId);
        System.assertEquals(0, [SELECT Count() FROM ContentDocument]);
    }

    @IsTest
    static void uploadsToResolvedAccountFolderWhenStoredFolderIdIsStale() {
        Account accountRecord = new Account(
            Name = 'Folder Match',
            Nick_Name__c = 'Folder Match',
            SharePoint_Folder_Id__c = 'stale-account-folder'
        );
        insert accountRecord;

        LinkEaseController.configOverride = new SharePoint_Config__mdt(
            Drive_Id__c = 'drive-id',
            Accounts_Parent_Item_Id__c = 'accounts-parent'
        );
        Test.setMock(HttpCalloutMock.class, new AccountFolderResolutionMock());

        Test.startTest();
        LinkEaseController.UploadResult result = LinkEaseController.uploadFile(
            accountRecord.Id,
            'resolved.txt',
            EncodingUtil.base64Encode(Blob.valueOf('correct destination'))
        );
        Test.stopTest();

        System.assertEquals('correct-account-folder', result.folderItemId);
        System.assertEquals('resolved-file-id', result.driveItemId);
    }

    @IsTest
    static void uploadsContractFilesToAccountAndCentralCdaFolders() {
        Account accountRecord = new Account(
            Name = 'Contract Upload Parent',
            SharePoint_Folder_Id__c = 'account-folder',
            SharePoint_Contract_Folder_Id__c = 'account-contract-folder'
        );
        insert accountRecord;
        Contract contractRecord = new Contract(
            AccountId = accountRecord.Id,
            StartDate = Date.today(),
            Status = 'Active',
            Type_of_Contract__c = '2-way CDA'
        );
        insert contractRecord;

        LinkEaseController.configOverride = new SharePoint_Config__mdt(
            Drive_Id__c = 'drive-id',
            CDA_Folder_Item_Id__c = 'central-cda-folder'
        );
        Test.setMock(HttpCalloutMock.class, new ContractFolderUploadMock());

        Test.startTest();
        LinkEaseController.uploadFile(contractRecord.Id, 'contract.txt', 'Y29udHJhY3Q=');
        Test.stopTest();
    }

    @IsTest
    static void rejectsRestrictedFileTypes() {
        try {
            LinkEaseController.uploadFile(
                '001000000000000AAA', 'unsafe.exe', EncodingUtil.base64Encode(Blob.valueOf('file'))
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
        insert accountRecord;
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
        insert accountRecord;
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
    static void requiresTheSpecificOpportunityFolder() {
        Account accountRecord = new Account(
            Name = 'Opportunity Parent', Nick_Name__c = 'Opportunity Parent',
            SharePoint_Folder_Id__c = 'account-folder'
        );
        insert accountRecord;
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
            LinkEaseController.uploadFile(recordId, fileName, base64Data);
            System.assert(false, 'Expected an AuraHandledException.');
        } catch (AuraHandledException exceptionRecord) {
            System.assert(exceptionRecord.getMessage().contains(expectedMessage));
        }
    }
}
