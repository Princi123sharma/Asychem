public with sharing class ActiveOrInactiveAccountChecker {
    @AuraEnabled(cacheable=true)
    public static OpportunityCounts fetchCounts(string accountId) {
        OpportunityCounts counts = new OpportunityCounts();
        counts.openOppsCount = getOpportunitiesCount(accountId);
        counts.activeContractsCount = getActiveContracts(accountId);
        return counts;
    }

    public static Integer getOpportunitiesCount(Id recordId) {
        List<Account> accList = [SELECT Id, Open_Opportunities_Last_6_Months__c FROM Account WHERE Id = :recordId LIMIT 1];
        
        if (!accList.isEmpty() && accList[0].Open_Opportunities_Last_6_Months__c != null) {
            return accList[0].Open_Opportunities_Last_6_Months__c.intValue();
        } else {
            return 0;
        }
    }
    
    public static Integer getActiveContracts(Id recordId) {
        List<Account> accList = [SELECT Id, Active_Contracts__c FROM Account WHERE Id = :recordId LIMIT 1];
        
        if (!accList.isEmpty() && accList[0].Active_Contracts__c != null) {
            return accList[0].Active_Contracts__c.intValue();
        } else {
            return 0;
        }
    }
    

    Public class OpportunityCounts {
        @AuraEnabled public Integer openOppsCount { get; set; }
        @AuraEnabled public Integer activeContractsCount{get; set;}
    }
}