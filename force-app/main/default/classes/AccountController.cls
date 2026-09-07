public with sharing class AccountController {
    @AuraEnabled(cacheable=true)
    public static List<sobject> getRelatedAccounts(Id parentId) {
        String ObjectName = String.valueOf(parentId.getsobjecttype());
        if(ObjectName=='Account'){
            List<Account> ParentIdList =[Select Id,ParentId from Account where Id =:parentId];
            if( ParentIdList[0].ParentId !=NULL){
                return [SELECT Id, Name, Industry, Phone, Website FROM Account WHERE ((Id=:ParentIdList[0].ParentId OR ParentId =:ParentIdList[0].ParentId ) AND Id!=:parentId)];
            }
        }
        else if(ObjectName=='Account_Catalog__c'){
            
            List<Account_Catalog__c> accCatList = [Select Id,Parent_Account_Catalog__c,Account__c from Account_Catalog__c where Id=:parentId ];
        if( accCatList[0].Parent_Account_Catalog__c !=NULL){
                return [SELECT Id,Name,Account__c,Parent_Account_Catalog__c FROM Account_Catalog__c WHERE ((Id=:accCatList[0].Parent_Account_Catalog__c OR Parent_Account_Catalog__c = :accCatList[0].Parent_Account_Catalog__c ) AND Id!=:parentId)];
            }
        }
        return null;
    }
}