public with sharing class customNewOpportunityLwcController{
    public customNewOpportunityLwcController(){
    }
 
    @AuraEnabled
    public static Opportunity saveOpportunityObj(String oppObjstr){ 
        try{
            Map<String, Object> oppObjMap = (Map<String, Object>)JSON.deserializeUntyped(oppObjstr);
            Opportunity oppObj = new Opportunity();
            oppObj.name = (String)oppObjMap.get('Name');
            oppObj.Id = oppObjMap.get('Id') == '' ? NULL : (Id)oppObjMap.get('Id');
            oppObj.stagename = (String)oppObjMap.get('StageName');
            oppObj.type = (String)oppObjMap.get('Type');
            oppObj.CloseDate = Date.valueOf((String)oppObjMap.get('CloseDate'));
            oppObj.accountId = (String)oppObjMap.get('AccountId');
            oppObj.Requesting_User__c = (String)oppObjMap.get('Requesting_User__c');
            oppObj.Bypass_Reason__c = (String)oppObjMap.get('Bypass_Reason__c');
            oppObj.Background_Comments__c = (String)oppObjMap.get('Background_Comments__c');
            oppObj.Due_Date_for_China__c = Date.valueOf((String)oppObjMap.get('Due_Date_for_China__c'));
            oppObj.Ship_to_Country__c = (String)oppObjMap.get('Ship_to_Country__c');
            oppObj.Date_RFP_due_to_Client__c = Date.valueOf((String)oppObjMap.get('Date_RFP_due_to_Client__c'));

            
            Id resolvedOwnerId = resolveOwnerId((String)oppObjMap.get('AccountId'));
            if (resolvedOwnerId != null) {
                oppObj.OwnerId = resolvedOwnerId;
            }

            upsert oppObj Id;
            
            return [Select Id,Name, CreatedById, CreatedBy.Name,AccountId, Account.Name,CreatedBy.Email, Requesting_User__c, Bypass_Reason__c,Background_Comments__c,Due_Date_for_China__c, Ship_to_Country__c, Date_RFP_due_to_Client__c FROM Opportunity WHERE Id = : oppObj.Id LIMIT 1];
        } catch (Exception e){
            system.debug('Exception:' + e + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Exception:' + e + '\n' + e.getStackTraceString());
        }
    }

    
    private static Id resolveOwnerId(String accountId) {
        
        Id accountOwnerId = new OwnerResolver().getAccountOwner(accountId);
        if (accountOwnerId != null) {
            return accountOwnerId;
        }
        
        return UserInfo.getUserId();
    }

    
    private without sharing class OwnerResolver {
        public Id getAccountOwner(String accountId) {
            if (String.isBlank(accountId)) return null;
            List<Account> accounts = [SELECT OwnerId FROM Account WHERE Id = :accountId LIMIT 1];
            return accounts.isEmpty() ? null : accounts[0].OwnerId;
        }
    }

    @AuraEnabled
    public static Compound__c saveCompoundObj(String compoundObjstr){
        String compoundId = null;
        try{
            Map<String, Object> compoundObjMap = (Map<String, Object>)JSON.deserializeUntyped(compoundObjstr);
            
            
            Compound__c compoundObj = new Compound__c();
            compoundObj.name = (String)compoundObjMap.get('Name');
            compoundObj.Id = compoundObjMap.get('Id') == '' ? NULL : (Id)compoundObjMap.get('Id');
            compoundObj.Molecule_Type__c = (String)compoundObjMap.get('Molecule_Type__c');
            compoundObj.Phase_of_Development__c = (String)compoundObjMap.get('Phase_of_Development__c');
            compoundObj.EH_S_Requirements__c = (String)compoundObjMap.get('EH_S_Requirements__c');
            compoundObj.Regulatory_Class__c = (String)compoundObjMap.get('Regulatory_Class__c');
            compoundObj.GMP_Requirements__c = (String)compoundObjMap.get('GMP_Requirements__c');
            compoundObj.Therapeutic_Area__c = (String)compoundObjMap.get('Therapeutic_Area__c');
            
            upsert compoundObj;

            Opportunity_Compound__c opportunityCompound = new Opportunity_Compound__c();
            List<Opportunity_Compound__c> compoundList = [SELECT Id 
                                                         FROM Opportunity_Compound__c 
                                                         WHERE Compound__c = :compoundObj.Id LIMIT 1];
            if(compoundList.size() > 0){ 
                opportunityCompound.Id = compoundList[0].Id;              
            }
            opportunityCompound.Compound__c = compoundObj.Id;
            opportunityCompound.Opportunity__c = (String)compoundObjMap.get('Opportunity__c');
            upsert opportunityCompound Id;
            
            
            
            
            for(Opportunity opp:[Select AccountId from Opportunity where Id=:opportunityCompound.Opportunity__c]){
                //compoundObj.Account__c =opp.AccountId;
                compoundObj.Account__c =opp.AccountId;
                compoundObj.opportunity__c=opp.Id;
                upsert compoundObj;
            }
            
            
            //add existing compounds
           /* List<Object> selectedCompoundObjects = (List<Object>)compoundObjMap.get('SelectedCompoundIds');
            Set<Id> compoundIds = new Set<Id>();
            for (Object cObj : selectedCompoundObjects){
                String cId = (String)cObj;
                if (cId != null){
                    compoundIds.add(cId);
                }
            }
            List<Compound__c> existingcompounds=[select Id,Opportunity__c,Account__c from Compound__c WHERE 
            Id IN:compoundIds];
            for(Compound__c c:existingcompounds){
                c.opportunity__c=compoundObj.opportunity__c;
            }
            update existingcompounds;*/
            
            return [Select Id, Name,opportunity__c,Molecule_Type__c,Phase_of_Development__c,EH_S_Requirements__c,Regulatory_Class__c,GMP_Requirements__c FROM Compound__c WHERE Id =: compoundObj.Id LIMIT 1];
        } catch (Exception e){
            system.debug('Exception:' + e + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Exception:' + e + '\n' + e.getStackTraceString());
        }
    }

    @AuraEnabled
    public static ExistingCompoundRecords saveExistingCompoundRecord(String compoundId, String opportunityId, String productClass){
        
        List<Opportunity_Compound__c> existingCompoundRecords = new List<Opportunity_Compound__c>();
        Set<Id> compoundIds  = new set<Id>();
        List<FileDetails> fileRecords = new List<FileDetails>();
        FileDetails fileRecord = new FileDetails();
        ExistingCompoundRecords existingCompound = new ExistingCompoundRecords();
        try{
            Opportunity_Compound__c opportunityCompound = new Opportunity_Compound__c();
            opportunityCompound.Compound__c = compoundId;
            opportunityCompound.Opportunity__c = opportunityId;
            opportunityCompound.Product_Class__c = productClass;
            insert opportunityCompound;
            list<Opportunity> listOpportunity = [Select AccountId from Opportunity where Id=:opportunityId];
            Id AccountId=listOpportunity.get(0).AccountId;
            for(Compound__c com:[Select Account__c from Compound__c where Id=:compoundId]){
                com.Account__c=AccountId;
                update com;
            }
            
            existingCompoundRecords = [SELECT Id, Name, Opportunity__c,Opportunity__r.Name, Compound__c,Compound__r.Name FROM Opportunity_Compound__c WHERE Opportunity__c =: opportunityId];
            
            if(existingCompoundRecords.size()>0){
                for(Opportunity_Compound__c opportunityCompoundRec : existingCompoundRecords){
                    compoundIds.add(opportunityCompoundRec.Compound__c);
                }
                for(ContentVersion contentVersionRec : [Select Id, ContentDocumentId, Title FROM ContentVersion WHERE FirstPublishLocationId In : compoundIds]){
                    fileRecord = new FileDetails();
                    fileRecord.name = contentVersionRec.Title;
                    fileRecord.documentId = contentVersionRec.ContentDocumentId;
                    fileRecord.contentVersionId = contentVersionRec.Id;
                    fileRecords.add(fileRecord);
                }

                existingCompound.opportuityCompoundRecs = existingCompoundRecords;//Returns new Opportunity compound.
                existingCompound.fileRecs = fileRecords;//Return assiociated files from the contentVersion.
                return existingCompound;
            }
        } catch (Exception e){
            system.debug('Exception:' + e + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Exception:' + e + '\n' + e.getStackTraceString());
        }
        return null;
    }

    @AuraEnabled
    public static Quote saveQuoteObj(String quoteObjstr){
        String quoteId = null;
        try{
            Map<String, Object> quoteObjMap = (Map<String, Object>)JSON.deserializeUntyped(quoteObjstr);
            String description = (String)quoteObjMap.get('Description__c');
            Quote quoteObj = new Quote();
            quoteObj.Id = quoteObjMap.get('Id') == '' ? NULL : (Id)quoteObjMap.get('Id');
            quoteObj.name = (String)quoteObjMap.get('Name');
            quoteObj.opportunityId = (String)quoteObjMap.get('OpportunityId');
            quoteObj.Use_of_Product__c = (String)quoteObjMap.get('Use_of_Product__c');
            quoteObj.Scope_of_Work__c = (String)quoteObjMap.get('Scope_of_Work__c');
            quoteObj.Materials_Provided_by_Client__c = (String)quoteObjMap.get('Materials_Provided_by_Client__c');
            quoteObj.Description__c = description;
            if((String)quoteObjMap.get('Quote_due_to_Client__c') != null){
                quoteObj.Quote_due_to_Client__c = Date.valueOf((String)quoteObjMap.get('Quote_due_to_Client__c'));
            }
            //insert quoteObj;
            quoteObj.Id = quoteObj.Id;
            quoteObj.Description__c = description;
            upsert quoteObj Id;
            return quoteObj;
        } catch (Exception e){
            system.debug('Exception:' + e + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Exception:' + e + '\n' + e.getStackTraceString());
        }
        //return quoteId;
    }

    @AuraEnabled
    public static EmailFeature getEmailSettings(){
        EmailFeature emailfeature = new EmailFeature();
        List<OrgWideEmailAddress> addresses = [SELECT Id, DisplayName, Address
                                               FROM OrgWideEmailAddress
                                               WHERE DisplayName = 'ASYMCHEM'];
        if (!addresses.isEmpty()){
            emailfeature.FromAddress = addresses[0].Address;
        }
        List<Compound__c> cmplist=new List<Compound__c>();
        for(Compound__c cmp:[SELECT Id,Name,Opportunity__c
        FROM Compound__c LIMIT 5]){
            cmplist.add(cmp);
        }
        emailfeature.compoundList=cmplist;
        return emailfeature;
    }

    @AuraEnabled
    public static void sendEmailAttachments(String pemailsettings){
        Map<String, Object> emailmap = (Map<String, Object>)JSON.deserializeUntyped(pemailsettings);
        List<Object> attachmentObjects = (List<Object>)emailmap.get('SelectedAttachmentIds');
        
        Boolean isExistingCompound = (Boolean)emailmap.get('isExistingCompound') != null ? (Boolean)emailmap.get('isExistingCompound') : false;
        String opportunityId = (String)emailmap.get('opportunityId');
        //String accountID = (String)emailmap.get('accountId');
       /* Opportunity opp = [SELECT AccountId FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
        Id accId = opp.AccountId;
        List<Contact> primaryContacts = [SELECT Id, Email FROM Contact WHERE AccountId = :accId AND Email != null LIMIT 1];
    
    if (primaryContacts.isEmpty()) {
        throw new AuraHandledException('No Contact found for this Account. An email cannot be saved to Activity without a related Contact.');
    }*/
        /*String accountId = (String)emailmap.get('accountId');
        String accountName = (String)emailmap.get('accountName');
        String opportunityName = (String)emailmap.get('opportunityName');
        String opportunityCreatedBy = (String)emailmap.get('opportunityCreatedBy');
        String emailSubject = '';
        emailSubject = 'A new opportunity under '+accountName+' has been created.';
        String emailBody = '';
        emailBody +='<p>A new opportunity has been created by <b> '+opportunityCreatedBy+ '</b><p>';
        emailBody +='<p>Account Name: <b>'+accountName+'</b></p>';
        emailBody +='<p>Opportunity Name: <b>'+opportunityName+'</b></p>';
        emailBody +='<p>Opportunity Link: <a href="'+URL.getSalesforceBaseUrl().toExternalForm()+'/'+opportunityId+'">click here</a></p>';
        if(String.isNotBlank((String)emailmap.get('dueDateForChina'))){
            emailBody +='<p>Due Date for China: '+(String)emailmap.get('dueDateForChina')+'</p>';
        }
        if(String.isNotBlank((String)emailmap.get('description'))){
            emailBody +='<p>Background Comments: '+(String)emailmap.get('description')+'</p>';
        }
        if(String.isNotBlank((String)emailmap.get('compoundId'))){
            emailBody +='<p>Compound link: <a href="'+URL.getSalesforceBaseUrl().toExternalForm()+'/'+(String)emailmap.get('compoundId')+'">'+(String)emailmap.get('compoundName')+'</a></p>';
        }

        if(String.isNotBlank((String)emailmap.get('moleculeType'))){
            emailBody +='<p>Molecule Type: '+(String)emailmap.get('moleculeType')+'</p>';
        }
        if(String.isNotBlank((String)emailmap.get('PhaseofDevelopment'))){
            emailBody +='<p>Phase of Development : '+(String)emailmap.get('PhaseofDevelopment')+'</p>';
        }
        if(String.isNotBlank((String)emailmap.get('EHSRequirements'))){
            emailBody +='<p>EHS Requirements: '+(String)emailmap.get('EHSRequirements')+'</p>';
        }
        if(String.isNotBlank((String)emailmap.get('GMPRequirements'))){
            emailBody +='<p>GMP Requirements: '+(String)emailmap.get('GMPRequirements')+'</p>';
        }
        if(String.isNotBlank((String)emailmap.get('RegulatoryClass'))){
            emailBody +='<p>Regulatory Class: '+(String)emailmap.get('RegulatoryClass')+'</p>';
        }

        if(String.isNotBlank((String)emailmap.get('quoteId'))){
            emailBody +='<p>Quote link: <a href="'+URL.getSalesforceBaseUrl().toExternalForm()+'/'+(String)emailmap.get('quoteId')+'">'+(String)emailmap.get('quoteName')+'</a></p>';
        }
        if(String.isNotBlank((String)emailmap.get('QuoteDueToClient'))){
            emailBody +='<p>Quote Due To Client: '+(String)emailmap.get('QuoteDueToClient')+'</p>';
        }*/
 
        String baseURL = URL.getSalesforceBaseUrl().toExternalForm();
        EmailTemplate emailTemplate = [Select Id FROM EmailTemplate WHERE DeveloperName = 'New_RFP' LIMIT 1];
        Set<Id> attachmentIds = new Set<Id>();
        for (Object attObj : attachmentObjects){
            String attId = (String)attObj;
            if (attId != null){
                attachmentIds.add(attId);
            }
        }
        String to = (String)emailmap.get('To');
        List<String> ToAddress = new List<String>();
        String cc = (String)emailmap.get('CC');
        List<String> cCAddress;
        if(to.contains(',')){
            ToAddress = to.split(',');
        }else{
            ToAddress.add(to);
        }
        if(cc != null && String.isNotBlank(cc) && cc.contains(',')){
            cCAddress = cc.split(',');
        }else if(cc != null && cc.length() > 0){ 
            cCAddress = new List<String>();
            cCAddress.add(cc);
        }

        
        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        // Set the recipient address
        message.setToAddresses(ToAddress);
        // Attach files to the message


        List<ContentVersion> files = [SELECT Id, ContentDocumentId, Title, Description, OwnerId, FileType, VersionData, ContentSize, Origin, FileExtension 
                                      FROM ContentVersion
                                      WHERE ContentDocumentId IN :attachmentIds];

        List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
        Map<String,String> contentTypeMap=new Map<String,String>();
        contentTypeMap.put('JPG','image/jpg');
        contentTypeMap.put('PNG','image/png');
        contentTypeMap.put('PDF','application/pdf');
        contentTypeMap.put('TXT','text/html');
        contentTypeMap.put('WORD_X','application/doc');
        contentTypeMap.put('WORD','application/doc');
        contentTypeMap.put('EXCEL_X','application/vnd.ms-excel');
        for (ContentVersion file : files){
            Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
            efa.setFileName(file.Title + '.' + file.FileExtension );
            efa.setBody(file.VersionData);            
            String fileContentType = String.isNotBlank(contentTypeMap.get((file.FileType).toUpperCase())) ? contentTypeMap.get((file.FileType).toUpperCase()) : 'application/octet-stream';
            efa.setContentType(fileContentType.toUpperCase());
            attachments.add(efa);
        }
        message.setTargetObjectId(userinfo.getUserId()); 
        message.setFileAttachments(attachments);
        message.setWhatId(opportunityId);
        message.setTemplateID(emailTemplate.Id);         
        message.setSaveAsActivity(false); 
        if(cCAddress != null && cCAddress.size() > 0){
            message.setCcAddresses(cCAddress);
        }
        
        // Set the message sender address
        List<OrgWideEmailAddress> addresses = [SELECT Id, DisplayName
                                               FROM OrgWideEmailAddress
                                               WHERE DisplayName = 'ASYMCHEM'];
        if (!addresses.isEmpty()){
            message.setOrgWideEmailAddressId(addresses[0].Id);
        }
        System.debug('CC Address::'+cCAddress);
        Savepoint sp = Database.setSavepoint();
        if (!Test.isRunningTest()) {
        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{message});
        }
        Database.rollback(sp);
        
        String emailBody = '';
        if (message.getHTMLBody() != null) {
            emailBody = message.getHTMLBody().replace('BASEURL', baseURL + '/' + opportunityId);
        }

        if(isExistingCompound){
            emailBody = emailBody.replace('display:none;','display:block;');
        }
        //To avoid TargetObject Id field.
        Messaging.SingleEmailMessage emailToSend = new Messaging.SingleEmailMessage();
        emailToSend.setTargetObjectId(userinfo.getUserId());
        emailToSend.setWhatId(opportunityId);
        emailToSend.setToAddresses(message.getToAddresses());
        if(message.getCcAddresses() != null){
            emailToSend.setCcAddresses(message.getCcAddresses());
        }
        emailToSend.setPlainTextBody(message.getPlainTextBody());
        emailToSend.setHTMLBody(emailBody);
        emailToSend.setSubject(message.getSubject());
        emailToSend.setSaveAsActivity(false); 
        emailToSend.setFileAttachments(message.getFileAttachments());
        //emailToSend.setTreatTargetObjectAsRecipient(false);
        if (!Test.isRunningTest()) {
        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{emailToSend});
        }
    }

    @AuraEnabled
    public static Boolean checkContractHasActiveStatus(String accountId){
        try{
            Account acc = [SELECT Id, ParentId FROM Account WHERE Id =: accountId limit 1];

            List<Contract> contractList = [SELECT Id, Status FROM Contract WHERE AccountId =: accountId OR AccountId =: acc.ParentId];

            for (Contract con : contractList) {
                if(con.Status == 'Active'){
                    return true;
                }
            }
            return false;
        } catch (Exception e){
            system.debug('Exception:' + e + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Exception:' + e + '\n' + e.getStackTraceString());
        }
    }

    public class EmailFeature{
        @AuraEnabled
        public String FromAddress;
        @AuraEnabled
        public String ToAddress;
        @AuraEnabled
        public String CCAddress;
        @AuraEnabled
        public List<Compound__c> compoundList;
    }

    public class FileDetails{
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String documentId;
        @AuraEnabled
        public String contentVersionId;
    }

    public class ExistingCompoundRecords{
        @AuraEnabled
        public List<Opportunity_Compound__c> opportuityCompoundRecs;
        @AuraEnabled
        public List<FileDetails> fileRecs;
    }
}