({
    init: function (cmp, event, helper) {
        cmp.set('v.columns',[
            {label: 'Account Name', fieldName: 'Account__r_LinkName', type: 'url', 
             typeAttributes: {label: { fieldName: 'Account__r_Name' }, target: '_blank'}},
            /*{ label: 'Opportunity', fieldName: 'Opportunity__c', type: 'text' },*/
            {label: 'CCL Number', fieldName: 'LinkName', type: 'url', 
             typeAttributes: {label: { fieldName: 'Name' }, target: '_blank'}}/*,
            { label: 'Regulatory Class', fieldName: 'Regulatory_Class__c', type: 'text' },
            { label: 'Molecule Type', fieldName: 'Molecule_Type__c', type: 'text' }*/
        ]);
        helper.fetchData(cmp, event, helper);
        helper.initColumnsWithActions(cmp, event, helper)
    },
    
    handleColumnsChange: function (cmp, event, helper) {
        helper.initColumnsWithActions(cmp, event, helper)
    },
    
    handleRowAction: function (cmp, event, helper) {
        var action = event.getParam('action');
        var row = event.getParam('row');
        var onRowActionHandler = cmp.get('v.onRowActionHandler');
        
        if (onRowActionHandler) {
            $A.enqueueAction(onRowActionHandler)
        } else {
            switch (action.name) {
                case 'edit':
                    helper.editRecord(cmp, row)
                    break;
                case 'delete':
                    helper.removeRecord(cmp, row)
                    break;
                case 'view_details':
                    helper.viewIndividualRecords(cmp, row)
                    break;
            }
        }
    },
    
    handleGotoRelatedList: function (cmp, event, helper) {
        var relatedListEvent = $A.get("e.force:navigateToRelatedList");
        relatedListEvent.setParams({
            "relatedListId": cmp.get("v.parentRelationshipApiName"),
            "parentRecordId": cmp.get("v.recordId")
        });
        relatedListEvent.fire();
        $A.get('e.force:refreshView').fire();
        //helper.fetchData(cmp, event, helper);
    },
    
    handleCreateRecord: function (cmp, event, helper) {
        var createRecordEvent = $A.get("e.force:createRecord");
        createRecordEvent.setParams({
            "entityApiName": cmp.get("v.sobjectApiName"),
            "defaultFieldValues": {
                [cmp.get("v.relatedFieldApiName")]: cmp.get("v.recordId")
            },
            "navigationLocation": "RELATED_LIST"
        });
        createRecordEvent.fire();
    },
    
    handleToastEvent: function (cmp, event, helper) {
        var eventType = event.getParam('type');
        var eventMessage = event.getParam('message');
        if (eventType == 'SUCCESS' && eventMessage.includes(cmp.get('v.sobjectLabel'))) {
            helper.fetchData(cmp, event, helper)
            event.stopPropagation();
        }
    },
})