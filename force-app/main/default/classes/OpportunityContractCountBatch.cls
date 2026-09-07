public class OpportunityContractCountBatch implements Database.Batchable<sObject>, Schedulable {

    public Database.QueryLocator start(Database.BatchableContext context) {
     
        TriggerControlHelper.isBatchRunning = true;
        return Database.getQueryLocator([SELECT Id FROM Account]);
    }

    public void execute(Database.BatchableContext context, List<sObject> scope) {
        Date sixMonthsAgo = Date.today().addMonths(-6);
            Set<Id> accountIds = new Set<Id>();

	
        for (SObject record : scope) {
        accountIds.add((Id)record.get('Id'));
    }

    if (accountIds.isEmpty()) {
        return; // No accounts to process
    }

        List<Opportunity> recentOpps = [
                SELECT Id, AccountId
                FROM Opportunity
                WHERE CreatedDate >= LAST_N_MONTHS:6
            AND AccountId IN :accountIds
        ];
        List<Contract> activeContracts = [
                SELECT Id, AccountId
                FROM Contract
                WHERE Status != 'Expired.' AND AccountId != NULL AND AccountId IN :accountIds
        ];

        List<Account> accountsToUpdate = new List<Account>();
        for (SObject accountSObj : scope) {
            Account account = (Account)accountSObj;
            Integer oppCount = 0;
            Integer contractCount = 0;
			
            for (Opportunity opp : recentOpps) {
                if (opp.AccountId == account.Id) {
                    oppCount++;
                }
            }
            for (Contract contract : activeContracts) {
                if (contract.AccountId == account.Id) {
                    contractCount++;
                }
            }
			System.debug('outer loop count' +oppCount);
            account.Open_Opportunities_Last_6_Months__c = oppCount;
            account.Active_Contracts__c = contractCount;
            accountsToUpdate.add(account);
        }

        //update accountsToUpdate;
      
        if (!accountsToUpdate.isEmpty()) {
                try {
                    // Partial update to avoid failure for all records
                    Database.SaveResult[] updateResults = Database.update(accountsToUpdate, false);
                    
                    // Logging failed records
                    for (Integer i = 0; i < updateResults.size(); i++) {
                        if (!updateResults[i].isSuccess()) {
                            for (Database.Error err : updateResults[i].getErrors()) {
                                System.debug('Failed to update Account ID: ' + accountsToUpdate[i].Id + '. Error: ' + err.getMessage());
                            }
                        }
                    }
                } catch (Exception e) {
                    System.debug('Batch Update Failed: ' + e.getMessage());
                }
            }
        
        
    }
    
    public void finish(Database.BatchableContext context) {
        TriggerControlHelper.isBatchRunning = false;
    }

    public void execute(SchedulableContext context) {
        Database.executeBatch(this);
    }

    public static void scheduleBatch() {
        String CRON_EXPRESSION = '0 0 0 * * ?'; // Run daily at 12 AM
        System.schedule('OpportunityContractCountBatch', CRON_EXPRESSION, new OpportunityContractCountBatch());
    }
}