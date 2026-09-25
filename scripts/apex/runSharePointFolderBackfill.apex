// Run once in a sandbox, validate the results, then run in production.
Database.executeBatch(new SharePointFolderReconciliationBatch(), 20);
