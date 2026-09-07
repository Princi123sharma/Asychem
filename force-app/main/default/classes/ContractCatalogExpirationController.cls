public without sharing class ContractCatalogExpirationController {
  @AuraEnabled(cacheable=true)
  public static List<Contract_Catalog__c> getContract(Integer months ,  String contractType) {
      Date today = Date.today();
      Date targetDate = today.addMonths(months);
     String userId = UserInfo.getUserId();
     String loggedInUserName = UserInfo.getName();
		system.debug('loggedInUserName ' + loggedInUserName);
      system.debug('contractType ' + contractType);
      if (contractType == 'MyContract') {
        return [
          SELECT Name,Account_Name__c,Contract_ID__c, Account_Catalog__c,
          Account_Catalog__r.Name, EndDate__c, Type_of_Contract__c,Account_Owner__c
          FROM Contract_Catalog__c
          WHERE Account_Owner__c=:loggedInUserName
          AND EndDate__c >= :today
          AND EndDate__c <= :targetDate
      ];
      }
      else {
        return [
          SELECT Name,Account_Name__c,Contract_ID__c, Account_Catalog__c,
          Account_Catalog__r.Name, EndDate__c, Type_of_Contract__c,Account_Owner__c
          FROM Contract_Catalog__c
          WHERE EndDate__c >= :today
          AND EndDate__c <= :targetDate
      ];
      }  
  }

}