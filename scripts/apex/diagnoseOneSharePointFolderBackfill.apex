// Processes one incomplete sandbox Account and emits the folder-service result to its debug log.
new SharePointFolderCreationJob(new Set<Id>{ '0015Y00002nM5cMQAS' }).execute(null);
System.debug('FOLDER_BACKFILL_DIAGNOSTIC_COMPLETED');
