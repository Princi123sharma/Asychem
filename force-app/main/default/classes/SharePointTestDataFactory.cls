@IsTest
public class SharePointTestDataFactory {
    public static Account insertAccount(String name) {
        Account accountRecord = new Account(Name = name, Nick_Name__c = name);
        TriggerControlHelper.isBatchRunning = true;
        try { insert accountRecord; } finally { TriggerControlHelper.isBatchRunning = false; }
        return accountRecord;
    }

    public static Contract insertReviewContract(Id accountId) {
        Contract contractRecord = new Contract(
            AccountId = accountId, StartDate = Date.today(), Status = 'Client Review',
            Type_of_Contract__c = '2-way CDA'
        );
        insert contractRecord;
        return contractRecord;
    }
}
