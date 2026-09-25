// Read-only verification of the Aura-enabled LinkEase endpoint.
List<LinkEaseController.SharePointFile> files = LinkEaseController.getFiles('001cf00001HvpGZAAZ');
System.debug('LINKEASE_FILE_LOAD=SUCCESS, FILE_COUNT=' + files.size());
