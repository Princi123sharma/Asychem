public class BoxFilesHelper {
    
    public static void uploadFiles(ContentDocumentLink fileToUpload){
        list<ContentDocumentLink> links=[SELECT Id, LinkedEntityId, ContentDocumentId, Visibility, IsDeleted, ShareType,ContentDocument.Title,ContentDocument.FileType  FROM ContentDocumentLink where ContentDocumentId=:fileToUpload.ContentDocumentId];
        String accId=null;
        String oppId=null;
        String conId=null;
        system.debug('links- '+links);
        for(ContentDocumentLink temp : links){
            if(((String)temp.LinkedEntityId).startsWith('001')){
                accId=temp.LinkedEntityId;
            }
            if(((String)temp.LinkedEntityId).startsWith('006')){
                oppId=temp.LinkedEntityId;
            }
            if(((String)temp.LinkedEntityId).startsWith('800')){
                conId=temp.LinkedEntityId;
            }
        }
        system.debug('accId	' + accId + 'oppId	' +oppId +'conId '+ conId);
        String folderId='';
        if(accId!=NULL){
            Account acc=[SELECT ID,Name,Folder_Id__c,Contract_Folder_Id__c,Opportunities_Folder_Id__c FROM Account where id=:accId];
            if(acc.Folder_Id__c == NULL)
            {
                BoxController.createAccountFolders(Id.valueOf(accId));
            }
            Account acc2=[SELECT ID,Name,Folder_Id__c,Contract_Folder_Id__c,Opportunities_Folder_Id__c FROM Account where id=:accId];
            
            folderId=acc2.Folder_Id__c;
        }
        if(oppId!=NULL){
            Opportunity op=[SELECT AccountId,Account.Folder_Id__c,Account.Opportunities_Folder_Id__c FROM opportunity where id=:oppId];
            
            if(op.AccountId!=NUll){
                if(op.Account.Folder_Id__c == null)
                {
                    BoxController.createAccountFolders(op.AccountId);
                }
                Opportunity op2=[SELECT AccountId,Account.Folder_Id__c,Account.Opportunities_Folder_Id__c FROM opportunity where id=:oppId];
                folderId=op2.Account.Opportunities_Folder_Id__c;
            }
        }
        String contractFolderId='';
        if(conId!=NULL){
            Contract con=[SELECT Account.Contract_Folder_Id__c,AccountId,Account.Folder_Id__c,Type_of_Contract__c,Status FROM Contract where id=:conId];
            if(con.AccountId!=NUll){
                if(con.Account.Folder_Id__c == null)
                {
                    BoxController.createAccountFolders(con.AccountId);
                }
                Contract con2=[SELECT Account.Contract_Folder_Id__c,AccountId,Account.Folder_Id__c,Type_of_Contract__c,Status FROM Contract where id=:conId];
                folderId=con2.Account.Contract_Folder_Id__c;
            }
            if(con.Status=='Active' && (con.Type_of_Contract__c=='1-way CDA' || con.Type_of_Contract__c=='3-way CDA' || con.Type_of_Contract__c=='2-way CDA')){
                contractFolderId=BoxFolderIds__c.getValues('LegalContract').CDA__c;
            }
            else if(con.Status=='Active' && con.Type_of_Contract__c=='LOI'){
                contractFolderId=BoxFolderIds__c.getValues('LegalContract').LOI__c;
            }
            else if(con.Status=='Active' && con.Type_of_Contract__c=='MSA'){
                contractFolderId=BoxFolderIds__c.getValues('LegalContract').MSA__c;
            }
            else if(con.Status=='Active' && con.Type_of_Contract__c=='CSA'){
                contractFolderId=BoxFolderIds__c.getValues('LegalContract').CSA__c;
            }
            else if(con.Status=='Active' && con.Type_of_Contract__c=='QAA'){
                contractFolderId=BoxFolderIds__c.getValues('LegalContract').QAA__c;
            }
            else if(con.Status=='Executive Review' || con.Status=='Client Review' || con.Status=='Internal Review'){
                if(con.Status=='Executive Review'){
                    contractFolderId=BoxFolderIds__c.getValues('LegalContract').Executive_Review__c;
                }
                else if(con.Status=='Client Review'){
                    contractFolderId=BoxFolderIds__c.getValues('LegalContract').Client_Review__c;
                }
                else{
                    contractFolderId=BoxFolderIds__c.getValues('LegalContract').Internal_Review__c;
                }          
            }
            else if((con.Status=='Terminated' || con.Status=='Expired' || con.Status=='Draft') && con.Type_of_Contract__c=='Not Checked'){
                contractFolderId=BoxFolderIds__c.getValues('LegalContract').Misc__c;
            }
        }
        
        ContentVersion cv=[SELECT VersionData, Id,pathonclient, ContentDocumentId, Title, ContentSize FROM ContentVersion where ContentDocumentId=:fileToUpload.ContentDocumentId];
        
        if(folderId!=''){
            BoxController.uploadFileToBox(cv.VersionData,folderId,cv.pathonclient);
        }
        if(contractFolderId!=''){
            BoxController.uploadFileToBox(cv.VersionData,contractFolderId,cv.pathonclient);
        }
    }
}