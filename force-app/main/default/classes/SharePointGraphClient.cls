public with sharing class SharePointGraphClient {
    private static final String NAMED_CREDENTIAL = 'callout:SharePoint_Graph';
    private static final Integer TIMEOUT_MS = 120000;
    private static final Set<String> RESTRICTED_FILE_EXTENSIONS = new Set<String>{
        'exe', 'bat', 'cmd', 'scr'
    };

    public class DriveItem {
        public String id { get; set; }
        public String name { get; set; }
        public Long size { get; set; }
        public String lastModifiedDateTime { get; set; }
        public String lastModifiedBy { get; set; }
        public String webUrl { get; set; }
        public Boolean isFolder { get; set; }
    }

    public class DeltaItem {
        public String id { get; set; }
        public Boolean deleted { get; set; }
    }

    public class DeltaResult {
        public List<DeltaItem> items { get; set; }
        public String nextLink { get; set; }
        public String deltaLink { get; set; }
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

        return parseDriveItem(response.getBody());
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

    /** Returns the files directly inside an existing SharePoint folder. */
    public static List<DriveItem> listFiles(String driveId, String folderItemId) {
        List<DriveItem> children = listFolderContents(driveId, folderItemId);
        List<DriveItem> files = new List<DriveItem>();
        for (DriveItem child : children) {
            if (child.isFolder != true) files.add(child);
        }
        return files;
    }

    /** Returns both folders and files directly inside a SharePoint folder. */
    public static List<DriveItem> listFolderContents(String driveId, String folderItemId) {
        if (String.isBlank(driveId) || String.isBlank(folderItemId)) {
            throw new SharePointException('Drive ID and folder item ID are required.');
        }

        HttpRequest request = new HttpRequest();
        request.setEndpoint(
            NAMED_CREDENTIAL +
            '/v1.0/drives/' + EncodingUtil.urlEncode(driveId, 'UTF-8') +
            '/items/' + EncodingUtil.urlEncode(folderItemId, 'UTF-8') +
            '/children?$select=id,name,size,lastModifiedDateTime,lastModifiedBy,webUrl,file,folder&$orderby=name'
        );
        request.setMethod('GET');
        request.setHeader('Accept', 'application/json');
        request.setTimeout(TIMEOUT_MS);

        HttpResponse response = new Http().send(request);
        if (response.getStatusCode() != 200) {
            throw new SharePointException(
                'Could not retrieve SharePoint files. HTTP ' +
                response.getStatusCode() + ': ' + response.getBody()
            );
        }

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        List<Object> values = (List<Object>) responseMap.get('value');
        List<DriveItem> children = new List<DriveItem>();
        if (values == null) return children;
        for (Object value : values) {
            children.add(parseDriveItem((Map<String, Object>) value));
        }
        return children;
    }

    public static DeltaResult getDelta(String driveId, String deltaLink) {
        if (String.isBlank(driveId) && String.isBlank(deltaLink)) {
            throw new SharePointException('Drive ID or delta link is required.');
        }

        HttpRequest request = new HttpRequest();
        request.setEndpoint(String.isBlank(deltaLink)
            ? NAMED_CREDENTIAL + '/v1.0/drives/' + EncodingUtil.urlEncode(driveId, 'UTF-8') + '/root/delta'
            : toNamedCredentialEndpoint(deltaLink));
        request.setMethod('GET');
        request.setHeader('Accept', 'application/json');
        request.setTimeout(TIMEOUT_MS);

        HttpResponse response = new Http().send(request);
        if (response.getStatusCode() != 200) {
            throw new SharePointException(
                'Could not retrieve SharePoint changes. HTTP ' +
                response.getStatusCode() + ': ' + response.getBody()
            );
        }

        Map<String, Object> responseMap =
            (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        DeltaResult result = new DeltaResult();
        result.items = new List<DeltaItem>();
        result.nextLink = responseMap.containsKey('@odata.nextLink')
            ? String.valueOf(responseMap.get('@odata.nextLink')) : null;
        result.deltaLink = responseMap.containsKey('@odata.deltaLink')
            ? String.valueOf(responseMap.get('@odata.deltaLink')) : null;
        List<Object> values = (List<Object>) responseMap.get('value');
        if (values == null) return result;

        for (Object value : values) {
            Map<String, Object> itemMap = (Map<String, Object>) value;
            DeltaItem item = new DeltaItem();
            item.id = itemMap.containsKey('id') ? String.valueOf(itemMap.get('id')) : null;
            item.deleted = itemMap.containsKey('deleted') && itemMap.get('deleted') != null;
            result.items.add(item);
        }
        return result;
    }

    private static String toNamedCredentialEndpoint(String graphLink) {
        Integer hostEnd = graphLink.indexOf('.com');
        return hostEnd >= 0
            ? NAMED_CREDENTIAL + graphLink.substring(hostEnd + 4)
            : graphLink;
    }

    /**
     * Uploads a Salesforce File version to an existing SharePoint folder.
     * A file with the same name is replaced by Microsoft Graph.
     */
    public static DriveItem uploadFile(
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

        return parseDriveItem(response.getBody());
    }

    /**
     * Graph DriveItem JSON includes nested objects (file, folder, lastModifiedBy).
     * Apex JSON.deserialize into DriveItem would throw "Illegal value for primitive"
     * because lastModifiedBy is a String on our class.
     */
    private static DriveItem parseDriveItem(String jsonBody) {
        return parseDriveItem((Map<String, Object>) JSON.deserializeUntyped(jsonBody));
    }

    private static DriveItem parseDriveItem(Map<String, Object> item) {
        DriveItem child = new DriveItem();
        child.id = stringValue(item.get('id'));
        child.name = stringValue(item.get('name'));
        child.size = longValue(item.get('size'));
        child.lastModifiedDateTime = stringValue(item.get('lastModifiedDateTime'));
        child.webUrl = stringValue(item.get('webUrl'));
        child.isFolder = item.get('folder') != null;
        child.lastModifiedBy = displayNameFrom(item.get('lastModifiedBy'));
        return child;
    }

    private static String stringValue(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private static Long longValue(Object value) {
        if (value == null) return null;
        if (value instanceof Long) return (Long) value;
        if (value instanceof Integer) return Long.valueOf(String.valueOf(value));
        if (value instanceof Decimal) return ((Decimal) value).longValue();
        try {
            return Long.valueOf(String.valueOf(value));
        } catch (Exception ignored) {
            return null;
        }
    }

    private static String displayNameFrom(Object lastModifiedBy) {
        if (!(lastModifiedBy instanceof Map<String, Object>)) return null;
        Map<String, Object> modifiedBy = (Map<String, Object>) lastModifiedBy;
        String userName = nestedDisplayName(modifiedBy.get('user'));
        if (String.isNotBlank(userName)) return userName;
        return nestedDisplayName(modifiedBy.get('application'));
    }

    private static String nestedDisplayName(Object identity) {
        if (!(identity instanceof Map<String, Object>)) return null;
        Object displayName = ((Map<String, Object>) identity).get('displayName');
        return displayName == null ? null : String.valueOf(displayName);
    }
}
