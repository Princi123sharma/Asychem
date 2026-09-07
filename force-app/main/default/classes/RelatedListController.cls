public class RelatedListController {
    public static final String FIELDS_PARAM = 'fields';
    public static final String NUMBER_OF_RECORDS_PARAM = 'numberOfRecords';
    public static final String RECORD_ID_PARAM = 'recordId';
    public static final String SOBJECT_API_NAME_PARAM = 'sobjectApiName';
    public static final String PARENT_WHERE_CAUSE = 'isParent';
    public static final String PARENT_ID = 'parentId';
    public static final String QUOTE_SCREEN = 'isQuoteScreen';
    public static final String LOCATION_SCREEN = 'isLocationScreen';
    public static final String INDIVIDUAL_FAMILY_LIST = 'individualFamilyList';
    public static final String SOBJECT_LABEL_PARAM = 'sobjectLabel';
    public static final String SOBJECT_LABEL_PLURAL_PARAM = 'sobjectLabelPlural';
    public static final String PARENT_RELATIONSHIP_API_NAME_PARAM = 'parentRelationshipApiName';
    public static final String RELATED_FIELD_API_NAME_PARAM = 'relatedFieldApiName';
    public static final String SORTED_DIRECTION_PARAM = 'sortedDirection';
    public static final String SORTED_BY_PARAM = 'sortedBy';
    public static final String RECORDS_PARAM = 'records';
    public static final String ICON_NAME_PARAM = 'iconName';
    @AuraEnabled
    public static String initData(String jsonData){
        Map<String, Object> requestMap = (Map<String, Object>)JSON.deserializeUntyped(jsonData);
        Map<String, Object> responseMap = new Map<String, Object>();
        String recordId = (String)requestMap.get(RECORD_ID_PARAM);
        responseMap.put(RECORDS_PARAM, getRecords(recordId));
        
        String sobjectApiName = 'Compound__c';
        responseMap.put(ICON_NAME_PARAM, getIconName(sobjectApiName));
        String relatedFieldApiName = 'Account__c';
        responseMap.put(PARENT_RELATIONSHIP_API_NAME_PARAM, getParentRelationshipName(recordId, sobjectApiName, relatedFieldApiName));
        
        Schema.SObjectType sobjectType = Schema.getGlobalDescribe().get(sobjectApiName);
        Schema.DescribeSObjectResult sobjectDescribe = sobjectType.getDescribe();
        responseMap.put(SOBJECT_LABEL_PARAM, sobjectDescribe.getLabel());
        responseMap.put(SOBJECT_LABEL_PLURAL_PARAM, sobjectDescribe.getLabelPlural());
        return JSON.serialize(responseMap);
    }
    
    @AuraEnabled
    public static List<Compound__c> getRecords(String accountId){
        Set<Id> accountIds = new Set<Id>();
        accountIds.add(accountId);
        for(Account acc : [Select Id FROM Account WHERE ParentId =: accountId]){
            accountIds.add(acc.Id);
        }
        List<Compound__c> compoundRecords = [SELECT Id, Name, Opportunity__c, CCL__c, Account__c, Account__r.Name FROM Compound__c WHERE Account__c IN : accountIds];
        return compoundRecords;
    }
    
    private static String getParentRelationshipName(Id recordId, String childSobjectApiName, String relatedFieldApiName){
        Schema.DescribeSObjectResult descrRes = recordId.getSObjectType().getDescribe();
        String name;
        for (Schema.ChildRelationship cr : descrRes.getChildRelationships()){
            if (cr.getChildSObject().getDescribe().getName() == childSobjectApiName && cr.getField().getDescribe().getName() == relatedFieldApiName){
                name = cr.getRelationshipName();
                break;
            }
        }
        return name;
    }
    
    @AuraEnabled
    public static Boolean deleteRecord(Id recordId){
        Sobject sobj = recordId.getSObjectType().newSObject(recordId);
        Database.DeleteResult result = Database.delete(sobj, true);
        return result.isSuccess();
    }
    
    @AuraEnabled
    public static String getIconName(String sobjectApiName){
        String iconName;
        List<Schema.DescribeTabSetResult> tabSetDesc = Schema.DescribeTabs();
        List<Schema.DescribeTabResult> tabDesc = new List<Schema.DescribeTabResult>();
        List<Schema.DescribeIconResult> iconDesc = new List<Schema.DescribeIconResult>();
        
        for (Schema.DescribeTabSetResult tsr : tabSetDesc){
            tabDesc.addAll(tsr.getTabs());
        }
        
        for (Schema.DescribeTabResult tr : tabDesc){
            if (sobjectApiName == tr.getSobjectName()){
                if (tr.isCustom()){
                    iconDesc.addAll(tr.getIcons());
                } else{
                    iconName = 'standard:' + sobjectApiName.toLowerCase();
                }
            }
        }
        for (Schema.DescribeIconResult ir : iconDesc){
            if (ir.getContentType() == 'image/svg+xml'){
                iconName = 'custom:' + ir.getUrl().substringBetween('custom/', '.svg').substringBefore('_');
                break;
            }
        }
        return iconName;
    }
}