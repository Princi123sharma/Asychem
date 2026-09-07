@isTest
public class customNewOpportunityLwcControllerTest {
    @testSetup 
    public static void setupMethod(){
        Test.startTest();
        Test.setMock(HttpCalloutMock.class,new Mock());
        BoxCCredentials__c customSetting = new BoxCCredentials__c(name='CredentialsBox',Client_Id__c='12345678',Client_Secret__c='12345678',Access_Token__c='12345678',Refresh_Token__c='12345678');
        insert customSetting;
        BoxFolderIds__c folder = new BoxFolderIds__c(name='LegalContract',Client_Review__c='123456');
        insert folder;
        BoxFolderIds__c folder2 = new BoxFolderIds__c(name='Account',Accounts__c='123456');
        insert folder2; 
        
        Account acc = new Account();
        acc.Name = 'Test 1';
        acc.Nick_Name__c = 'Test 1';
        insert acc; 
        
        Contact con = new COntact(); 
        con.LastName = 'Test contact'; 
        con.AccountId = acc.Id;
        con.email = 'test@mail.com';
        insert con;
        
        Opportunity opp = new Opportunity();
        opp.Name = 'Test opportunity';
        opp.contactId = con.Id;
        opp.StageName = 'Inquiry Received';
        opp.Type = 'New Business';
        opp.CloseDate = System.today();
        opp.AccountId = acc.Id;
        opp.Background_Comments__c = 'Test 123';
        opp.Ship_to_Country__c = 'UK to US';
        opp.Due_Date_for_China__c = Date.today().addDays(1);
        opp.Date_RFP_due_to_Client__c = Date.today().addDays(1);
        insert opp;
        
        Compound__c compound = new Compound__c();
        compound.Name = 'Test compound';
        compound.opportunity__c = opp.Id;
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
        
        Contentversion cv = new Contentversion();
        cv.Title = 'Test 123';
        cv.PathOnClient = 'Test';
        cv.FirstPublishLocationId = compound.Id;
        cv.VersionData = EncodingUtil.base64Decode(EncodingUtil.urlEncode('Unit Test Attachment Body','UTF-8'));
        insert cv;
        TEST.stopTest();
    }
    
    @isTest
    public static void testMethod1(){
        //  bx.isCallback=true;       
        //   bx.getAuthUrl();
        //  BoxController.refreshAccessToken();
        //  bx.redirectOnCallback();
        List<Opportunity> opp = [Select Id, Name, StageName,Background_Comments__c,Due_Date_for_China__c, Type, CloseDate, Ship_to_Country__c, Date_RFP_due_to_Client__c, AccountId FROM Opportunity LIMIT 1];
        Map<String, Object> oppObjMap = new Map<String,Object>();
        oppObjMap.put('Name',opp[0].Name);
        oppObjMap.put('StageName',opp[0].StageName);
        oppObjMap.put('Type',opp[0].Type);
        oppObjMap.put('CloseDate',opp[0].CloseDate);
        oppObjMap.put('AccountId',opp[0].AccountId);
        oppObjMap.put('Background_Comments__c',opp[0].Background_Comments__c);
        oppObjMap.put('Due_Date_for_China__c',opp[0].Due_Date_for_China__c);
        oppObjMap.put('Date_RFP_due_to_Client__c',opp[0].Date_RFP_due_to_Client__c);
        oppObjMap.put('Ship_to_Country__c',opp[0].Ship_to_Country__c);
        
        List<Compound__c> comp = [Select Id, Name, Opportunity__c,Molecule_Type__c,Phase_of_Development__c,GMP_Requirements__c,Regulatory_Class__c,EH_S_Requirements__c FROM Compound__c WHERE Opportunity__c =: opp[0].Id];
        Map<String,Object> compoundObjMap = new Map<String, Object>();
        List<Object> selectedCompoundObjects = new List<Object>();
        selectedCompoundObjects.add(comp[0].Id);
        compoundObjMap.put('Name',comp[0].Name);
        compoundObjMap.put('Opportunity__c',comp[0].Opportunity__c);
        compoundObjMap.put('Molecule_Type__c',comp[0].Molecule_Type__c);
        compoundObjMap.put('Phase_of_Development__c',comp[0].Phase_of_Development__c);
        compoundObjMap.put('EH_S_Requirements__c',comp[0].EH_S_Requirements__c);
        compoundObjMap.put('Regulatory_Class__c',comp[0].Regulatory_Class__c);
        compoundObjMap.put('SelectedCompoundIds',selectedCompoundObjects);
        
        List<Quote> quote = [Select Id, OpportunityId,Description__c,Quote_due_to_Client__c FROM Quote WHERE OpportunityId =: opp[0].Id];
        Map<String,Object> quoteObjMap = new Map<String, Object>();
        quoteObjMap.put('Name',quote[0].Id);
        quoteObjMap.put('OpportunityId',quote[0].OpportunityId);
        quoteObjMap.put('Description__c',quote[0].Description__c);
        quoteObjMap.put('Quote_due_to_Client__c',quote[0].Quote_due_to_Client__c);
        
        List<Object> attachmentsIds = new List<Object>();
        for(ContentVersion conVersion: [Select Id, ContentDocumentId FROM ContentVersion]){
            attachmentsIds.add(conVersion.ContentDocumentId);
        }
        
        Map<String, Object> emailmap = new Map<String,Object>();
        emailmap.put('SelectedAttachmentIds', attachmentsIds);
        emailmap.put('To', 'test@gmail.com');
        emailmap.put('isExistingCompound', true);
        emailmap.put('opportunityId', opp[0].Id);
        
        customNewOpportunityLwcController constructor = new customNewOpportunityLwcController();
        customNewOpportunityLwcController.saveOpportunityObj(JSON.serialize(oppObjMap));
        customNewOpportunityLwcController.saveCompoundObj(JSON.serialize(compoundObjMap));
        customNewOpportunityLwcController.saveExistingCompoundRecord(comp[0].Id,opp[0].Id,'Test');
        customNewOpportunityLwcController.saveQuoteObj(JSON.serialize(quoteObjMap));
        customNewOpportunityLwcController.getEmailSettings();
        customNewOpportunityLwcController.sendEmailAttachments(JSON.serialize(emailmap));
        customNewOpportunityLwcController.checkContractHasActiveStatus(opp[0].AccountId);
            }
    public class Mock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) 
        {   system.debug('getEnd'+req.getEndpoint());
         if(req.getEndpoint().indexOf('https://api.box.com/2.0/folders')!=-1){
             
             string fullJson = '{"id":"123456"}';
             HTTPResponse res = new HTTPResponse();
             res.setBody(fullJson);
             res.setStatusCode(201);
             res.setStatus('OK');
             return res;   
         }
         else if(req.getEndpoint().indexOf('https://upload.box.com/api/2.0/files/')!=-1){
             string fullJson = '{}';
             HTTPResponse res = new HTTPResponse();
             res.setBody(fullJson);
             res.setStatusCode(201);
             res.setStatus('OK');
             return res;   
         } 
         else if(req.getEndpoint().indexOf('https://api.box.com/oauth2/token')!=-1){
             string fullJson = '{"access_token" : "1234567890" , "refresh_token" : "12345678"}';
             HTTPResponse res = new HTTPResponse();
             res.setBody(fullJson);
             res.setStatusCode(200);
             res.setStatus('OK');
             return res;  
         }
         else{
             string fullJson = '{"access_token" : "1234567890" , "refresh_token" : "12345678"}';
             HTTPResponse res = new HTTPResponse();
             res.setBody(fullJson);
             res.setStatusCode(200);
             res.setStatus('OK');
             return res;  
         }
        }
    }
}