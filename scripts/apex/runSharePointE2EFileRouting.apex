// Disposable sandbox/SharePoint routing test. Do not run in production.
Id accountId = '001cf00001HvpGZAAZ';
Opportunity opportunityRecord = new Opportunity(
    Name = 'SP E2E Opportunity', AccountId = accountId,
    StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
);
insert opportunityRecord;
Contract contractRecord = new Contract(
    AccountId = accountId, StartDate = Date.today(),
    Status = 'Client Review', Type_of_Contract__c = '2-way CDA'
);
insert contractRecord;

List<ContentVersion> versions = new List<ContentVersion>{
    new ContentVersion(Title = 'sp-e2e-account', PathOnClient = 'sp-e2e-account.txt',
        VersionData = Blob.valueOf('Account routing verification'), FirstPublishLocationId = accountId),
    new ContentVersion(Title = 'sp-e2e-opportunity', PathOnClient = 'sp-e2e-opportunity.txt',
        VersionData = Blob.valueOf('Opportunity routing verification'), FirstPublishLocationId = opportunityRecord.Id),
    new ContentVersion(Title = 'sp-e2e-contract', PathOnClient = 'sp-e2e-contract.txt',
        VersionData = Blob.valueOf('Contract routing verification'), FirstPublishLocationId = contractRecord.Id)
};
insert versions;
System.debug('E2E_OPPORTUNITY_ID=' + opportunityRecord.Id + ', E2E_CONTRACT_ID=' + contractRecord.Id);
