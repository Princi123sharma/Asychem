public with sharing class SharePointFolderCreationJob
    implements Queueable, Database.AllowsCallouts {

    // Each account needs up to three Graph callouts. Keep each Queueable below
    // Salesforce's 100-callout transaction limit.
    private static final Integer ACCOUNTS_PER_JOB = 30;

    private Set<Id> accountIds;

    public SharePointFolderCreationJob(Set<Id> accountIds) {
        this.accountIds = accountIds == null ? new Set<Id>() : accountIds;
    }

    public void execute(QueueableContext context) {
        List<Id> pendingAccountIds = new List<Id>(accountIds);
        Integer accountsToProcess = Math.min(
            ACCOUNTS_PER_JOB,
            pendingAccountIds.size()
        );

        for (Integer index = 0; index < accountsToProcess; index++) {
            SharePointFolderService.createAccountFolders(pendingAccountIds[index]);
        }

        if (pendingAccountIds.size() > accountsToProcess) {
            Set<Id> remainingAccountIds = new Set<Id>();
            for (Integer index = accountsToProcess; index < pendingAccountIds.size(); index++) {
                remainingAccountIds.add(pendingAccountIds[index]);
            }

            System.enqueueJob(new SharePointFolderCreationJob(remainingAccountIds));
        }
    }
}