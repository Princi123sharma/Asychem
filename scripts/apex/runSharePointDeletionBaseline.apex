// Establishes the Microsoft Graph delta baseline; it does not delete any file.
new SharePointDeletionSync().execute(null);
System.debug('DELETION_BASELINE_RUN=COMPLETED');
