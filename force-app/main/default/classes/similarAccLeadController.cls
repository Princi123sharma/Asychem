public with sharing class similarAccLeadController {
    public similarAccLeadController() {

    }
    @AuraEnabled(cacheable=true)
    public static List<Lead> findSimilarLeads(Id leadId, String companyName) {
        //String companyNameQuery =  companyName.split(' ')[0] + '%';
        //return [SELECT Id, Name, Company, Email, Phone FROM Lead WHERE Id != :leadId AND Company LIKE :companyNameQuery];
        List<String> strexclude=new List<String>{'llc','llc.','biosciences','therapeutics','inc','inc.','corp','biotech','biomed','bio','pharmaceuticals','pharma','limited','spa','gmbh','lab','laboratory'};
        List<String> companyNameQuery =  companyName.split(' ');
        String soqlQuery = 'SELECT Id, Name, Company, Email, Phone FROM Lead WHERE Id != :leadId AND (Company LIKE \'%'+String.join(companyNameQuery, '%\' OR Company LIKE \'%')+'%\')';
		List<Lead> Leads = Database.query(soqlQuery);
        Set<Lead> listLeadToreturn=new Set<Lead>();
        for(Lead lead:Leads){
            List<String>listLead=lead.Company.split(' ');
            for(String strLead:listLead){
                if(companyNameQuery.contains(strLead) && !(strexclude.contains(strLead.toLowercase()))){
                    listLeadToreturn.add(lead);
                }
            }
        }
        List<Lead> myList = new List<Lead>(listLeadToreturn);
        return myList;
    }
}