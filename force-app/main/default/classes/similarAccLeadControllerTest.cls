@isTest
public class similarAccLeadControllerTest {
    @TestSetup
    static void testSetupMethod(){
        Lead ld = new Lead();
        ld.Account_Created_from_Lead_check__c = false;
        ld.Company = 'Test untangle';
        ld.LastName = 'test';
        ld.NickName__c = 'nickName';
        ld.Status = 'Qualified';
        ld.Country = 'United States';  
        ld.State = 'California'; 
        Insert ld;
        Lead ld1 = new Lead();
        ld1.Account_Created_from_Lead_check__c = false;
        ld1.Company = 'untangle';
        ld1.LastName = 'test';
        ld1.NickName__c = 'nickName';
        ld1.Status = 'Qualified';
        ld1.Country = 'United States';  // Add valid country
        ld1.State = 'California'; 
        Insert ld1;
    }
    @isTest
    static void testMethod1(){
        Test.startTest();
        Lead ld = [SELECT Id from Lead WHERE Company = 'untangle' LIMIT 1];
        list<lead> lslst = similarAccLeadController.findsimilarLeads(ld.Id,'Test');
        
        Test.stopTest();
        System.assertEquals(1,lslst.size());
    }
}