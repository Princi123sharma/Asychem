// Run once in the target org after deploying the SharePoint package.
// The name is intentionally stable: rerun only after deleting/replacing the old job.
System.schedule(
    'SharePoint deletion sync',
    '0 0 * * * ?',
    new SharePointDeletionSyncScheduler()
);
