public with sharing class activeInactiveAccountHandler {
    @AuraEnabled(cacheable=true)
    public static ActiveReason fetchReason(Id accId) {
        Id accountId = resolveAccountId(accId);
        Account accountRecord = [SELECT Id, Active__c, Client_Status__c FROM Account WHERE Id = :accountId];
        String finalStatus = String.isBlank(accountRecord.Client_Status__c)
            ? (accountRecord.Active__c ? 'Active' : 'Inactive')
            : accountRecord.Client_Status__c;
        Boolean activeStatus = finalStatus == 'Active';
        ActiveReason res = new ActiveReason();
        res.reason = new List<String>();
        res.isActive = activeStatus;
        res.status = finalStatus;
        Date sixMonthsAgo = Date.today().addMonths(-6);
        Date today = Date.today();

        if(activeStatus){
            List<Opportunity> accountHasOpps = [SELECT Id FROM Opportunity WHERE AccountId = :accountId];

            if(!accountHasOpps.isEmpty()){
                // Fetch Opportunities, Quotes, and Contracts
                List<Opportunity> opps = [SELECT Id, StageName FROM Opportunity WHERE AccountId = :accountId AND StageName !='Closed Won'];
                List<Quote> quo = [SELECT Id FROM Quote WHERE AccountId = :accountId AND Status != 'Approved'];

                // Check for ongoing work or RFPs in Opportunities and Quotes
                if (opps.isEmpty() && quo.isEmpty()) {
                    res.reason.add('Client has current PO with on-going work.');
                } else {
                    Boolean hasActiveRFP = false;
                    Set<Id> opportunityIds = new Set<Id>();

                    for (Opportunity op : opps) {
                        if (op.StageName == 'Inquiry Received') {
                            res.reason.add('Client has received an RFP or has Active RFPs within the past 6 months');
                            hasActiveRFP = true;
                            break;
                        } else if (op.StageName == 'Proposal Sent' || op.StageName == 'Proposal Revision' || op.StageName == '90% Forecast' || op.StageName == 'PO in Process') {
                                opportunityIds.add(op.Id);
                        }
                    }

                    if (!opportunityIds.isEmpty()) {
                        List<OpportunityHistory> opportunityHistories = [SELECT OpportunityId, CreatedDate FROM OpportunityHistory WHERE OpportunityId IN :opportunityIds AND CreatedDate > :sixMonthsAgo ORDER BY CreatedDate DESC];

                        for (OpportunityHistory history : opportunityHistories) {
                            res.reason.add('Client has received an RFP or has Active RFPs within the past 6 months');
                            hasActiveRFP = true;
                            break;
                        }
                    }

                    if (!hasActiveRFP) {
                        res.reason.add('Client has current PO with on-going work.');
                    }
                }
            }

            List<Contract> contracts = [SELECT Id FROM Contract WHERE AccountId = :accountId AND Status = 'Active' AND EndDate > :today];
            // Check for active contracts
            if (!contracts.isEmpty()) {
                res.reason.add('Client has active contracts.');
            }
        } else if (finalStatus == 'Pending') {
            res.reason.add('Client is currently on the Pending Client List.');
        } else if (finalStatus == 'Inactive') {
            res.reason.add('Client is currently on the Inactive Client List.');
        }
        return res;
    }

    private static Id resolveAccountId(Id recordId) {
        if (recordId == null) {
            return null;
        }

        if (recordId.getSObjectType() == Account.SObjectType) {
            return recordId;
        }

        if (recordId.getSObjectType() == Account_Catalog__c.SObjectType) {
            Account_Catalog__c catalogRecord = [
                SELECT Account__c
                FROM Account_Catalog__c
                WHERE Id = :recordId
                LIMIT 1
            ];
            return catalogRecord.Account__c;
        }

        return recordId;
    }

    @AuraEnabled
    public static InactiveRuleResult evaluateFirstInactiveRule(Id accId) {
        InactiveRuleResult result = new InactiveRuleResult();
        result.accountsEvaluated = 0;
        result.accountsWithOldCda = 0;
        result.accountsWithRfp = 0;
        result.accountsUpdated = 0;
        result.updatedAccountIds = new List<Id>();
        result.errors = new List<String>();

        if (accId == null) {
            result.errors.add('Account Id is required.');
            return result;
        }

        try {
            result.accountsEvaluated = 1;
            DateTime sixMonthsAgo = DateTime.now().addMonths(-6);
            Set<String> cdaTypes = new Set<String>{'1-way CDA', '2-way CDA', '3-way CDA'};

            List<Contract> oldCdaContracts = [
                SELECT Id
                FROM Contract
                WHERE AccountId = :accId
                AND Type_of_Contract__c IN :cdaTypes
                AND ActivatedDate != null
                AND ActivatedDate <= :sixMonthsAgo
                LIMIT 1
            ];
            Boolean hasOldCda = !oldCdaContracts.isEmpty();
            result.accountsWithOldCda = hasOldCda ? 1 : 0;

            List<Opportunity> rfpOpportunities = [
                SELECT Id
                FROM Opportunity
                WHERE AccountId = :accId
                AND Date_RFP_due_to_Client__c != null
                LIMIT 1
            ];
            Boolean hasRfp = !rfpOpportunities.isEmpty();
            result.accountsWithRfp = hasRfp ? 1 : 0;

            if (hasOldCda && !hasRfp) {
                Account accountToUpdate = new Account(
                    Id = accId,
                    Client_Status__c = 'Inactive',
                    Active__c = false
                );
                update accountToUpdate;
                result.accountsUpdated = 1;
                result.updatedAccountIds.add(accId);
            }
        } catch (Exception e) {
            result.errors.add(e.getMessage());
        }

        return result;
    }

    public class ActiveReason {
        @AuraEnabled public List<String> reason { get; set; }
        @AuraEnabled public Boolean isActive { get; set; }
        @AuraEnabled public String status { get; set; }
    }

    public class InactiveRuleResult {
        @AuraEnabled public Integer accountsEvaluated { get; set; }
        @AuraEnabled public Integer accountsWithOldCda { get; set; }
        @AuraEnabled public Integer accountsWithRfp { get; set; }
        @AuraEnabled public Integer accountsUpdated { get; set; }
        @AuraEnabled public List<Id> updatedAccountIds { get; set; }
        @AuraEnabled public List<String> errors { get; set; }
    }
}