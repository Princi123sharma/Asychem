@isTest
public class RelatedListControllerTest {
    @testSetup 
    static void setupMethod(){
        Account acc = new Account();
        acc.Name = 'Test 1';
        acc.Nick_Name__c = 'Test';
        insert acc; 
        
        Contact con = new COntact(); 
        con.LastName = 'Test contact'; 
        con.AccountId = acc.Id;
        insert con;
        
        Opportunity opp = new Opportunity();
        opp.Name = 'Test opportunity';
        opp.contactId = con.Id;
        opp.StageName = 'Inquiry Received';
        opp.Type = 'New Business';
        opp.CloseDate = System.today();
        opp.AccountId = acc.Id;
        opp.Background_Comments__c = 'Test 123';
        opp.Due_Date_for_China__c = Date.today().addDays(1);
        insert opp;
        
        Compound__c compound = new Compound__c();
        compound.Name = 'Test compound';
        compound.opportunity__c = opp.Id;
        compound.Account__c = acc.Id;
        compound.Molecule_Type__c = '';
        compound.Phase_of_Development__c = '';
        compound.EH_S_Requirements__c = '';
        compound.Regulatory_Class__c = '';
        compound.GMP_Requirements__c = '';
        compound.Molecule_Type__c = 'Antibody';
        insert compound;
        
        Quote q = new Quote();
        q.Name = 'Test Quote';
        q.OpportunityId = opp.Id;
        q.Description__c=opp.Background_Comments__c;
        q.Quote_due_to_Client__c = Date.today();
        insert q;
        
    }
    
    @isTest
    static void testMethod1(){
        List<Account> acc = [Select Id FROM Account LIMIT 1];
        List<Compound__c> comp = [Select Id, Name, Opportunity__c,Molecule_Type__c,Phase_of_Development__c,GMP_Requirements__c,Regulatory_Class__c,EH_S_Requirements__c FROM Compound__c WHERE Account__c =: acc[0].Id];
        
        Map<String, Object> jsonData = new Map<String,Object>();
        jsonData.put('recordId',acc[0].Id);
        
        RelatedListController.initData(JSON.serialize(jsonData));
        RelatedListController.deleteRecord(comp[0].Id);
    }
}