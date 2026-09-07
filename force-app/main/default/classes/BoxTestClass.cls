@isTest
public class BoxTestClass {
    @testSetup
    static void setup() {      
        BoxCCredentials__c customSetting = new BoxCCredentials__c(name='Box_Credentials',Client_Id__c='12345678',Client_Secret__c='12345678',Access_Token__c='12345678',Refresh_Token__c='12345678');
        insert customSetting;
        BoxFolderIds__c folder = new BoxFolderIds__c(
            name='LegalContract',
            Client_Review__c='123456',
            CDA__c='123456',
            LOI__c='123456',
            MSA__c='123456',
            CSA__c='123456',
            QAA__c='123456',
            Executive_Review__c='123456',
            Internal_Review__c='123456',
            Misc__c='123456'
        );
        insert folder;
        BoxFolderIds__c folder2 = new BoxFolderIds__c(name='Account',Accounts__c='123456');
        insert folder2;
        
    }
    
    @isTest
    public static void boxtestMethod(){
        Test.setMock(HttpCalloutMock.class,new Mock());
        
        account a= new account(name='test',Nick_Name__c='test',Folder_Id__c='123456',Opportunities_Folder_Id__c='123456',Contract_Folder_Id__c='123456');
        insert a;
        account a2= new account(name='testing',Nick_Name__c='check');
        insert a2;
        opportunity op = new opportunity(name='testop',accountId=a.Id,StageName='Proposal Sent',LeadSource='Existing Client');
        op.CloseDate=system.today();
        insert op;
        Contract co = new Contract(accountId=a.Id,Type_of_Contract__c='2-way CDA',status='Client Review');
        insert co;
        
        ContentVersion content=new ContentVersion(); 
        content.Title='Header_Picture1'; 
        content.PathOnClient='/' + content.Title + '.jpg'; 
        Blob bodyBlob=Blob.valueOf('Unit Test ContentVersion Body'); 
        content.VersionData=bodyBlob;
        content.origin = 'H';
        insert content;
        
        ContentDocumentLink contentlink=new ContentDocumentLink();
        contentlink.LinkedEntityId=a.id;
        contentlink.contentdocumentid=[select contentdocumentid from contentversion where id =: content.id].contentdocumentid;
        contentlink.ShareType = 'I';
        contentlink.Visibility = 'AllUsers';        
        insert contentlink;
        
        ContentDocumentLink contentlink2=new ContentDocumentLink();
        contentlink2.LinkedEntityId=co.id;
        contentlink2.contentdocumentid=[select contentdocumentid from contentversion where id =: content.id].contentdocumentid;
        contentlink2.ShareType = 'I';
        contentlink2.Visibility = 'AllUsers';         
        insert contentlink2;
        
        ContentDocumentLink contentlink3=new ContentDocumentLink();
        contentlink3.LinkedEntityId=op.id;
        contentlink3.contentdocumentid=[select contentdocumentid from contentversion where id =: content.id].contentdocumentid;
        contentlink3.ShareType = 'I';
        contentlink3.Visibility = 'AllUsers';         
        insert contentlink3;
        
        Test.startTest();
        // Test BoxFilesHelper.uploadFiles
        BoxFilesHelper.uploadFiles(contentlink);
        BoxFilesHelper.uploadFiles(contentlink2);
        BoxFilesHelper.uploadFiles(contentlink3);
        Test.stopTest();
    }
    
    @isTest
    public static void testBoxFilesHelperWithoutFolders(){
        Test.setMock(HttpCalloutMock.class,new Mock());
        
        account a= new account(name='test2',Nick_Name__c='test2');
        insert a;
        opportunity op = new opportunity(name='testop2',accountId=a.Id,StageName='Proposal Sent',LeadSource='Existing Client');
        op.CloseDate=system.today();
        insert op;
        
        ContentVersion content=new ContentVersion(); 
        content.Title='TestFile2'; 
        content.PathOnClient='/' + content.Title + '.pdf'; 
        content.VersionData=Blob.valueOf('Test Body'); 
        content.origin = 'H';
        insert content;
        
        ContentDocumentLink contentlink=new ContentDocumentLink();
        contentlink.LinkedEntityId=op.id;
        contentlink.contentdocumentid=[select contentdocumentid from contentversion where id =: content.id].contentdocumentid;
        contentlink.ShareType = 'I';
        contentlink.Visibility = 'AllUsers';        
        insert contentlink;
        
        Test.startTest();
        BoxFilesHelper.uploadFiles(contentlink);
        Test.stopTest();
    }
    
    @isTest
    public static void testBoxFilesHelperContractTypes(){
        Test.setMock(HttpCalloutMock.class,new Mock());
        
        account a= new account(name='test3',Nick_Name__c='test3',Folder_Id__c='123456',Contract_Folder_Id__c='123456');
        insert a;
        
        // Use only statuses that are valid in the org based on the existing test
        Contract co1 = new Contract(accountId=a.Id,Type_of_Contract__c='1-way CDA',status='Client Review');
        Contract co2 = new Contract(accountId=a.Id,Type_of_Contract__c='3-way CDA',status='Client Review');
        Contract co3 = new Contract(accountId=a.Id,Type_of_Contract__c='LOI',status='Executive Review');
        Contract co4 = new Contract(accountId=a.Id,Type_of_Contract__c='MSA',status='Executive Review');
        Contract co5 = new Contract(accountId=a.Id,Type_of_Contract__c='CSA',status='Internal Review');
        Contract co6 = new Contract(accountId=a.Id,Type_of_Contract__c='QAA',status='Client Review');
        insert new List<Contract>{co1,co2,co3,co4,co5,co6};
        
        ContentVersion content=new ContentVersion(); 
        content.Title='ContractFile'; 
        content.PathOnClient='/ContractFile.pdf'; 
        content.VersionData=Blob.valueOf('Contract Body'); 
        content.origin = 'H';
        insert content;
        
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for(Contract c : new List<Contract>{co1,co2,co3,co4,co5,co6}){
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.LinkedEntityId=c.id;
            cdl.contentdocumentid=[select contentdocumentid from contentversion where id =: content.id].contentdocumentid;
            cdl.ShareType = 'I';
            cdl.Visibility = 'AllUsers';
            links.add(cdl);
        }
        insert links;
        
        Test.startTest();
        for(ContentDocumentLink link : links){
            BoxFilesHelper.uploadFiles(link);
        }
        Test.stopTest();
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