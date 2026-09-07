public with sharing class CheckActiveInactiveAccountBatch implements Database.Batchable<sObject> {

    public Database.QueryLocator start(Database.BatchableContext context) {
        TriggerControlHelper.isBatchRunning = true;
        return Database.getQueryLocator([SELECT Id, Active__c FROM Account]);
    }

    public void execute(Database.BatchableContext context, List<Account> accounts) {
        Map<Id, Id> accIdOppIdMap = new Map<Id,Id>();

        Set<Id> accountIds = new Set<Id>();
        for(Account acc : accounts){
            accountIds.add(acc.Id);
        }
        
        for(Opportunity op : [SELECT Id, AccountId FROM Opportunity WHERE AccountId IN :accountIds]){
            accIdOppIdMap.put(op.AccountId, op.Id);
        }

        Date sixMonthsAgo = Date.today().addMonths(-6);
        Date today = Date.today();
        
        Map<Id, List<Opportunity>> oppsMap = new Map<Id, List<Opportunity>>();
        for(Opportunity opp : [SELECT Id, StageName, Date_of_Inquiry_del__c, AccountId FROM Opportunity WHERE AccountId IN :accountIds AND StageName != 'Closed Won']){
            List<Opportunity> oppList = new List<Opportunity>();
            oppList.add(opp);
            oppsMap.put(opp.AccountId, oppList);
        }
        
        Map<Id, List<Quote>> quotesMap = new Map<Id, List<Quote>>();
        for(Quote quo : [SELECT Id, AccountId, Status FROM Quote  WHERE AccountId IN :accountIds AND Status != 'Approved']){
            List<Quote> quoList = new List<Quote>();
            quoList.add(quo);
            quotesMap.put(quo.AccountId, quoList);
        }
        
        Map<Id, List<Contract>> contractsMap = new Map<Id, List<Contract>>();
        for(Contract contract : [SELECT Id, AccountId FROM Contract WHERE AccountId IN :accountIds AND (Status = 'Active' AND EndDate > :today)]){
            List<Contract> conList = new List<Contract>();
            conList.add(contract);
            contractsMap.put(contract.AccountId, conList);
        }
        Map<Id, Account> accountsToUpdateMap = new Map<Id, Account>(); 
        for(Account acc : accounts){
            if(accIdOppIdMap.containsKey(acc.Id)){
                Boolean response = false;
                if (!oppsMap.containsKey(acc.Id) && !quotesMap.containsKey(acc.Id)){ 
                    response = true;
                }
                else if(oppsMap.containsKey(acc.Id)){
                    response = checkOpportunityStatus(oppsMap.get(acc.Id), sixMonthsAgo);
                }
                acc.Active__c = response;
                accountsToUpdateMap.put(acc.Id, acc);
            } else {
                acc.Active__c = false;
                accountsToUpdateMap.put(acc.Id, acc);
            }

            if(contractsMap.containsKey(acc.Id)){
                acc.Active__c = true;
                accountsToUpdateMap.put(acc.Id, acc);
            } else {
                acc.Active__c = false;
                accountsToUpdateMap.put(acc.Id, acc);
            }
        }
        
        List<Account> accountsToUpdate = new List<Account>(accountsToUpdateMap.values());
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
    
    private Boolean checkOpportunityStatus(List<Opportunity> opps, Date sixMonthsAgo){
        Boolean response = false;
        
        for(Opportunity op : opps){
            if(op.StageName == 'Inquiry Received' && op.Date_of_Inquiry_del__c > sixMonthsAgo){
                response = true;
            }
            else if (op.StageName == 'Proposal Sent' || op.StageName == 'Proposal Revision' || op.StageName == '90% Forecast' || op.StageName == 'PO in Process'){
                List<OpportunityHistory> oph = [SELECT StageName, CreatedDate FROM OpportunityHistory WHERE OpportunityId = :op.Id AND StageName = :op.StageName ORDER BY CreatedDate DESC LIMIT 1];
                if (!oph.isEmpty() && oph[0].CreatedDate > sixMonthsAgo) {
                    response = true;
                }
            }
        }
        
        return response;
    }

    public void finish(Database.BatchableContext context) {
        TriggerControlHelper.isBatchRunning = false;
    }
}