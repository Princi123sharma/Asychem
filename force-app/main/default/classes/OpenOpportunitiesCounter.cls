public without sharing class OpenOpportunitiesCounter {

    @AuraEnabled(cacheable=true)
    public static OpportunityCounts fetchOpportunityCounts(string accountCatalogueId) {
        System.debug('accountCatalogueId ' + accountCatalogueId);
        Id accountId = [select Account__c from Account_Catalog__c where id = :accountCatalogueId]?.Account__c;
        System.debug('accountId ' + accountId);

        OpportunityCounts counts = new OpportunityCounts();
        counts.openOppsCount = countOpenOpportunities(accountId);
        counts.closedOppsCount = getClosedActiveOpportunities(accountId);
        return counts;
        }


    public static Integer countOpenOpportunities(Id accountId) {
        Date sixMonthsAgo = Date.today().addMonths(-6);
        List<Opportunity> openOpps = [
            SELECT Id
            FROM Opportunity
            WHERE IsClosed = false
            AND StageName NOT IN ('Closed Won', 'Closed Lost')
            AND CreatedDate >= :sixMonthsAgo
            AND AccountId = :accountId
        ];
        System.debug('openOpps ' + openOpps);

        return openOpps.size();
    }

    public static Integer getClosedActiveOpportunities(Id accountId) {
        Date currentDate = Date.today();
        List<Opportunity> closedOpps =   [SELECT Id, Name, estimated_project_deadline__c
                FROM Opportunity
                WHERE (StageName= 'Closed Won' OR StageName = 'Closed Lost') 
                AND estimated_project_deadline__c >= :currentDate
                AND AccountId = :accountId
                ];
                return closedOpps.size();
    }

  
    Public class OpportunityCounts {
        @AuraEnabled public Integer openOppsCount { get; set; }
        @AuraEnabled public Integer closedOppsCount { get; set; }
        }
        
        
}