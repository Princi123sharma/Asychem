public with sharing class SharePointGraphClient {
    private static final String NAMED_CREDENTIAL = 'callout:SharePoint_Graph';
    private static final Integer TIMEOUT_MS = 120000;
    private static final Set<String> RESTRICTED_FILE_EXTENSIONS = new Set<String>{
        'exe', 'bat', 'cmd', 'scr'
    };

    public class DriveItem {
        public String id { get; set; }
        public String name { get; set; }
    }

    public class SharePointException extends Exception {}

    public static DriveItem createFolder(
        String driveId,
        String parentItemId,
        String folderName
    ) {
        if (String.isBlank(driveId) ||
            String.isBlank(parentItemId) ||
            String.isBlank(folderName)) {
            throw new SharePointException('Drive ID, parent folder ID, and folder name are required.');
        }

        HttpRequest request = new HttpRequest();
        request.setEndpoint(
            NAMED_CREDENTIAL +
            '/v1.0/drives/' + EncodingUtil.urlEncode(driveId, 'UTF-8') +
            '/items/' + EncodingUtil.urlEncode(parentItemId, 'UTF-8') +
            '/children'
        );
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');
        request.setTimeout(TIMEOUT_MS);

        request.setBody(JSON.serialize(new Map<String, Object>{
            'name' => folderName,
            'folder' => new Map<String, Object>(),
            '@microsoft.graph.conflictBehavior' => 'fail'
        }));

        HttpResponse response = new Http().send(request);

        if (response.getStatusCode() != 201) {
            throw new SharePointException(
                'Could not create SharePoint folder. HTTP ' +
                response.getStatusCode() + ': ' + response.getBody()
            );
        }

        return (DriveItem) JSON.deserialize(response.getBody(), DriveItem.class);
    }

    public static String getFolderIdByName(
        String driveId,
        String parentFolderId,
        String folderName
    ) {
        if (String.isBlank(driveId) ||
            String.isBlank(parentFolderId) ||
            String.isBlank(folderName)) {
            return null;
        }

        HttpRequest request = new HttpRequest();
        request.setEndpoint(
            NAMED_CREDENTIAL +
            '/v1.0/drives/' + EncodingUtil.urlEncode(driveId, 'UTF-8') +
            '/items/' + EncodingUtil.urlEncode(parentFolderId, 'UTF-8') +
            '/children?$select=id,name'
        );
        request.setMethod('GET');
        request.setHeader('Accept', 'application/json');
        request.setTimeout(TIMEOUT_MS);

        HttpResponse response = new Http().send(request);
        if (response.getStatusCode() != 200) {
            return null;
        }

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        List<Object> items = (List<Object>) responseMap.get('value');
        if (items == null) {
            return null;
        }

        for (Object itemObj : items) {
            Map<String, Object> itemMap = (Map<String, Object>) itemObj;
            String itemName = String.valueOf(itemMap.get('name'));
            if (folderName == itemName) {
                return String.valueOf(itemMap.get('id'));
            }
        }

        return null;
    }

    /**
     * Uploads a Salesforce File version to an existing SharePoint folder.
     * A file with the same name is replaced by Microsoft Graph.
     */
    public static void uploadFile(
        String driveId,
        String folderItemId,
        String fileName,
        Blob fileData
    ) {
        if (String.isBlank(driveId) ||
            String.isBlank(folderItemId) ||
            String.isBlank(fileName) ||
            fileData == null) {
            throw new SharePointException(
                'Drive ID, folder item ID, file name, and file data are required.'
            );
        }

        String extension = fileName.substringAfterLast('.').toLowerCase();
        if (String.isNotBlank(extension) && RESTRICTED_FILE_EXTENSIONS.contains(extension)) {
            throw new SharePointException('File type not allowed: ' + extension);
        }

        String encodedFileName = EncodingUtil.urlEncode(fileName, 'UTF-8')
            .replace('+', '%20');

        HttpRequest request = new HttpRequest();
        request.setEndpoint(
            NAMED_CREDENTIAL +
            '/v1.0/drives/' + EncodingUtil.urlEncode(driveId, 'UTF-8') +
            '/items/' + EncodingUtil.urlEncode(folderItemId, 'UTF-8') +
            ':/' + encodedFileName +
            ':/content'
        );
        request.setMethod('PUT');
        request.setHeader('Content-Type', 'application/octet-stream');
        request.setTimeout(TIMEOUT_MS);
        request.setBodyAsBlob(fileData);

        HttpResponse response = new Http().send(request);
        if (response.getStatusCode() != 200 && response.getStatusCode() != 201) {
            throw new SharePointException(
                'Could not upload SharePoint file. HTTP ' +
                response.getStatusCode() + ': ' + response.getBody()
            );
        }
    }
}
