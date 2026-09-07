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
            response.setBody('{"id":"uploaded-file-id","name":"test file.pdf"}');
            return response;
        }
    }

    @IsTest
    static void uploadFileSendsGraphContentRequest() {
        Test.setMock(HttpCalloutMock.class, new UploadSuccessMock());

        Test.startTest();
        SharePointGraphClient.uploadFile(
            'drive-id',
            'folder-id',
            'test file.pdf',
            Blob.valueOf('test file body')
        );
        Test.stopTest();

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
    }
}
