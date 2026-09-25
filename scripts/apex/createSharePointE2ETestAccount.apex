// Disposable sandbox/SharePoint test record. Do not run in production.
Account accountRecord = new Account(
    Name = 'SP E2E Test ' + String.valueOf(System.now().getTime()),
    Nick_Name__c = 'SP E2E Test'
);
insert accountRecord;
System.debug('E2E_ACCOUNT_ID=' + accountRecord.Id);
