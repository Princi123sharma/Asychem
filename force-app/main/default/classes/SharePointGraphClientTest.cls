@IsTest
private class SharePointGraphClientTest {
    private class UploadSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            System.assertEquals('PUT', request.getMethod());
            System.assertEquals(
                'application/octet-stream',
                request.getHeader('Content-Type')
            );
            System.assert(
                request.getEndpoint().contains(
                    '/v1.0/drives/drive-id/items/folder-id:/test%20file.pdf:/content'
                ),
                'The upload should use the Microsoft Graph file-content endpoint.'
            );
            HttpResponse response = new HttpResponse();
            response.setStatusCode(201);
            response.setBody(
                '{"id":"uploaded-file-id","name":"test file.pdf","size":14,' +
                '"lastModifiedDateTime":"2026-09-14T00:00:00Z","webUrl":"https://example.test/file",' +
                '"file":{"mimeType":"application/pdf"},' +
                '"lastModifiedBy":{"application":{"displayName":"SharePoint App"}}}'
            );
            return response;
        }
    }

    private class DownloadUrlMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            System.assertEquals('GET', request.getMethod());
            System.assert(request.getEndpoint().contains('/v1.0/drives/drive-id/items/file-id'));
            System.assertEquals(-1, request.getEndpoint().indexOf('?$select='),
                'The item response supplies the preauthenticated download URL without a special projection.');
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"id":"file-id","file":{},"@microsoft.graph.downloadUrl":"https://download.example.test/file"}');
            return response;
        }
    }

    @IsTest
    static void uploadFileSendsGraphContentRequest() {
        Test.setMock(HttpCalloutMock.class, new UploadSuccessMock());

        Test.startTest();
        SharePointGraphClient.DriveItem uploaded = SharePointGraphClient.uploadFile(
            'drive-id',
            'folder-id',
            'test file.pdf',
            Blob.valueOf('test file body')
        );
        Test.stopTest();

        System.assertEquals('uploaded-file-id', uploaded.id);
        System.assertEquals('test file.pdf', uploaded.name);
        System.assertEquals('SharePoint App', uploaded.lastModifiedBy);
        System.assertEquals(false, uploaded.isFolder);
    }

    @IsTest
    static void getsTheDownloadUrlFromTheDriveItemResponse() {
        Test.setMock(HttpCalloutMock.class, new DownloadUrlMock());

        Test.startTest();
        String downloadUrl = SharePointGraphClient.getItemDownloadUrl('drive-id', 'file-id');
        Test.stopTest();

        System.assertEquals('https://download.example.test/file', downloadUrl);
    }

    @IsTest
    static void uploadFileRejectsMissingRequiredValues() {
        try {
            SharePointGraphClient.uploadFile(
                'drive-id',
                'folder-id',
                'file.txt',
                null
            );
            System.assert(false, 'Expected an exception for missing file data.');
        } catch (SharePointGraphClient.SharePointException exceptionRecord) {
            System.assert(exceptionRecord.getMessage().contains('file data'));
        }
    }

    @IsTest
    static void uploadFileRejectsUnsupportedFileType() {
        try {
            SharePointGraphClient.uploadFile(
                'drive-id',
                'folder-id',
                'virus.exe',
                Blob.valueOf('test file body')
            );
            System.assert(false, 'Expected an exception for restricted file types.');
        } catch (SharePointGraphClient.SharePointException exceptionRecord) {
            System.assert(exceptionRecord.getMessage().contains('not allowed'));
        }
    }

    @IsTest
    static void resolveContractFolderNameUsesContractTypeAndStatus() {
        System.assertEquals('CDA', SharePointFolderService.resolveContractFolderName('2-way CDA', 'Active'));
        System.assertEquals('LOI', SharePointFolderService.resolveContractFolderName('LOI', 'Active'));
        System.assertEquals('Executive Review', SharePointFolderService.resolveContractFolderName('Not Checked', 'Executive Review'));
        System.assertEquals('Misc', SharePointFolderService.resolveContractFolderName('Not Checked', 'Draft'));

        SharePoint_Config__mdt config = new SharePoint_Config__mdt(
            CDA_Item_ID__c = 'legacy-central-cda-folder',
            LOI_Item_ID__c = 'legacy-central-loi-folder',
            MSA_Item_ID__c = 'legacy-central-msa-folder',
            CSA_Item_ID__c = 'legacy-central-csa-folder',
            QAA_Item_ID__c = 'legacy-central-qaa-folder',
            Executive_Review_Item_ID__c = 'legacy-executive-review-folder',
            Client_Review_Item_ID__c = 'legacy-client-review-folder',
            Internal_Review_Item_ID__c = 'legacy-internal-review-folder',
            Misc_Item_ID__c = 'legacy-misc-folder'
        );
        System.assertEquals(
            'legacy-central-cda-folder',
            SharePointFolderService.resolveCentralContractFolderId(config, '2-way CDA', 'Active')
        );
        System.assertEquals(
            'legacy-central-loi-folder',
            SharePointFolderService.resolveCentralContractFolderId(config, 'LOI', 'Active')
        );
        System.assertEquals(
            'legacy-central-msa-folder',
            SharePointFolderService.resolveCentralContractFolderId(config, 'MSA', 'Active')
        );
        System.assertEquals(
            'legacy-central-csa-folder',
            SharePointFolderService.resolveCentralContractFolderId(config, 'CSA', 'Active')
        );
        System.assertEquals(
            'legacy-central-qaa-folder',
            SharePointFolderService.resolveCentralContractFolderId(config, 'QAA', 'Active')
        );
        System.assertEquals(
            'legacy-executive-review-folder',
            SharePointFolderService.resolveCentralContractFolderId(config, 'Not Checked', 'Executive Review')
        );
        System.assertEquals(
            'legacy-client-review-folder',
            SharePointFolderService.resolveCentralContractFolderId(config, 'Not Checked', 'Client Review')
        );
        System.assertEquals(
            'legacy-internal-review-folder',
            SharePointFolderService.resolveCentralContractFolderId(config, 'Not Checked', 'Internal Review')
        );
        System.assertEquals(
            'legacy-misc-folder',
            SharePointFolderService.resolveCentralContractFolderId(config, 'Not Checked', 'Draft')
        );
    }
}
