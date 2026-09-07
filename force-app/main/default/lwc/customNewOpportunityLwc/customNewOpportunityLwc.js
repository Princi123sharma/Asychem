import { LightningElement,api,track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import saveOpportunityRecord from "@salesforce/apex/customNewOpportunityLwcController.saveOpportunityObj";  
import saveCompoundRecord from "@salesforce/apex/customNewOpportunityLwcController.saveCompoundObj";  
import saveExistingCompoundRecord from "@salesforce/apex/customNewOpportunityLwcController.saveExistingCompoundRecord";  
import saveQuoteRecord from "@salesforce/apex/customNewOpportunityLwcController.saveQuoteObj";  
import emailsettings from "@salesforce/apex/customNewOpportunityLwcController.getEmailSettings";  
import sendemail from "@salesforce/apex/customNewOpportunityLwcController.sendEmailAttachments";  
import checkContractHasActiveStatus from "@salesforce/apex/customNewOpportunityLwcController.checkContractHasActiveStatus";  
import noActiveCDA from '@salesforce/label/c.No_Active_CDA';
import { NavigationMixin } from 'lightning/navigation';

const compoundColumns = [
    { label: 'Opportunity Compound', fieldName: 'Name' },    
    { label: 'Compound', fieldName: 'CompoundName' },
    { label: 'Opportunity', fieldName: 'OpportunityName' }    
];

export default class CustomNewOpportunityLwc extends NavigationMixin(LightningElement) {
    @api childObjectApiName = 'Opportunity'; //Contact is the default value
    @api targetFieldApiName = 'Requesting_User__c'; //AccountId is the default value
    @api fieldLabel = 'Requesting User';

    @track requestingUser=""; //store the record id of the selected 
    @track byPassReason="";
    handleValueSelcted(event) {
        this.requestingUser = JSON.parse(JSON.stringify(event.detail));
    }

    handleInputChange(event){
        this.byPassReason = event.target.value;
     }

    @api recordId;
    @track currentStep;
    @track isModalOpen=false;
    @track existingCompoundRecords=[];
    @track filesToDisplayInEmail=[];
    options = [
        {'label': 'Create Compound', 'value': 'create'},
        {'label': 'Existing Compound', 'value': 'update'},
    ];
    @track compoundBoolean = {
        "create" : false, "update" :false};
    @track oppObj={
        Id:'',
        AccountId:'',
        Name:'',
        StageName:'',
        CloseDate:'',
        Background_Comments__c:'',
        Due_Date_for_China__c:'',
        Date_RFP_due_to_Client__c:'',
        Ship_to_Country__c: '',
        Type:'',
        Requesting_User__c:'',
        Bypass_Reason__c:'',
        Disabled:false,
        FileUploadDisabled:true,
        NextButtonDisabled:true
    }

    @track compoundObj={
        Id:'',
        Disabled:false,
        Opportunity__c:'',
        Name:'',
        Molecule_Type__c:'',
        Phase_of_Development__c:'',
        EH_S_Requirements__c:'',
        Regulatory_Class__c:'',
        GMP_Requirements__c:'',
        NextButtonDisabled:true,
        FileUploadDisabled:true,
        SelectedCompoundIds:[]
    }
    compoundColumns = compoundColumns;
    @track quoteObj={
        Id:'',
        OpportunityId:'',
        Name:'',
        Disabled:false,
        NextButtonDisabled:true,
        FileUploadDisabled:true
    }
/*
       @track fileUpload={
        name:'',
        documentId:'',
        contentVersionId:''
        }*/

        @track emailFeatureSettings={
            From:'',
            To:'',
            CC:'',
            accountId:'',
            accountName:'',
            opportunityId:'',
            opportunityName:'',
            opportunityCreatedBy:'',
            SelectedAttachmentIds:[] ,
            dueDateForChina:'',
            shipToCountry: '',
            compoundId:'',
            compoundName:'',
            moleculeType:'',
            PhaseofDevelopment:'',
            EHSRequirements:'',
            GMPRequirements:'',
            RegulatoryClass:'',
            QuoteDueToClient:'',
            quoteId:'',
            quoteName:'' ,
            isExistingCompound:false       
        }

        @track opportunityAttachments=[];
        @track compoundAttachments=[];
        @track quoteAttachments=[];
        @track existingCompoundList=[];

        @track newScreen=false;
        @track noActive=false;
        @track label = {
            noActiveCDA
        };

    handleChange(event){
        if(event.detail.value === 'create'){
            this.compoundBoolean['create'] = true;
            this.compoundBoolean['update'] = false;
        }
        if(event.detail.value === 'update'){
            this.compoundBoolean['create'] = false;
            this.compoundBoolean['update'] = true;
        }
            
        console.log('selectedOption: ' +  event.detail.value);
    }
    
    connectedCallback() {
        // initialize component
        //this.currentStep = '1';
        this.opportunityAttachments = [];
        this.compoundAttachments = [];
        this.quoteAttachments = [];
        this.existingCompoundList=[];

        this.oppObj.AccountId=this.recordId;

        checkContractHasActiveStatus({ accountId: this.recordId})
        .then((result) => {
        if(result!=null && result!=undefined){
            if(result === false){
                this.newScreen = true;
            }else{
                this.newScreen = false;
                this.currentStep = '1';
            }
        }
        this.error = undefined;         
        })  
        .catch((error) => {  
            // this.error = error;  
        const evt = new ShowToastEvent({
            title: 'Error',
            message: error.body.message,
            variant: 'error'
        });
        this.dispatchEvent(evt);
        });  

        emailsettings()  
        .then((result) => {  
        if (result!=null) {             
            this.emailFeatureSettings.From=result.FromAddress;
            this.emailFeatureSettings.To=result.ToAddress;
            this.emailFeatureSettings.CC=result.CCAddress;
            this.existingCompoundList=result.compoundList;
        } 
        this.error = undefined;         
        })  
        .catch((error) => {  
       // this.error = error;  
        const evt = new ShowToastEvent({
            title: 'Error',
            message: error.body.message,
            variant: 'error'
        });
        this.dispatchEvent(evt);
    });         
    }

    hideNewScreen() {
        if(this.requestingUser != "" && this.byPassReason != ""){
            this.newScreen = false;
            this.currentStep = '1';
        }
        //this.noActive = true;
    }

    goBackToStepOne() {
        this.newScreen = false;
        this.currentStep = '1';

        this.template.querySelector('div.stepTwo').classList.add('slds-hide');
        this.template
            .querySelector('div.stepOne')
            .classList.remove('slds-hide');
    }

    goToStepTwo() {
        this.currentStep = '2';

        this.template.querySelector('div.stepOne').classList.add('slds-hide');
        this.template
            .querySelector('div.stepTwo')
            .classList.remove('slds-hide');
    }
    goBackToStepTwo() {
        this.currentStep = '2';

        this.template.querySelector('div.stepThree').classList.add('slds-hide');
        this.template.querySelector('div.stepFour').classList.add('slds-hide');
        this.template.querySelector('div.stepTwo').classList.remove('slds-hide');
    }
    goToStepThree() {
        this.currentStep = '3';

        this.template.querySelector('div.stepTwo').classList.add('slds-hide');
        this.template
            .querySelector('div.stepThree')
            .classList.remove('slds-hide');
    }

    goBackToStepThree() {
        this.currentStep = '3';

        this.template.querySelector('div.stepFour').classList.add('slds-hide');
        this.template.querySelector('div.stepThree').classList.remove('slds-hide');
    }

    goToStepFour() {
        this.currentStep = '4';

        this.template.querySelector('div.stepThree').classList.add('slds-hide');
        this.template
            .querySelector('div.stepFour')
            .classList.remove('slds-hide');
        }

        
    createNewOpportunity(){        
        this.isModalOpen=true;
    }
    closeMainModal(){
        this.isModalOpen=false;
        this.refreshComponent();
    }

    refreshComponent(){
        this.oppObj={
            Id:'',
            AccountId:'',
            Name:'',
            StageName:'',
            CloseDate:'',
            Background_Comments__c:'',
            Due_Date_for_China__c:'',
            Date_RFP_due_to_Client__c:'',
            Ship_to_Country__c: '', 
            Type:'',
            Requesting_User__c:'',
            Bypass_Reason__c:'',
            Disabled:false,
            FileUploadDisabled:true,
            NextButtonDisabled:true
        }
        this.compoundObj={
            Id:'',
            Disabled:false,
            Opportunity__c:'',
            Name:'',
            Molecule_Type__c:'',
            Phase_of_Development__c:'',
            EH_S_Requirements__c:'',
            Regulatory_Class__c:'',
            GMP_Requirements__c:'',
            NextButtonDisabled:true,
            FileUploadDisabled:true,
            SelectedCompoundIds:[]
        }
        this.quoteObj={
            Id:'',
            OpportunityId:'',
            Name:'',
            Disabled:false,
            NextButtonDisabled:true,
            FileUploadDisabled:true
        }
        this.existingCompoundRecords= [];
        this.emailFeatureSettings={
            From:'',
            To:'',
            CC:'',
            accountId:'',
            accountName:'',
            opportunityId:'',
            opportunityName:'',
            opportunityCreatedBy:'',
            SelectedAttachmentIds:[] ,
            dueDateForChina:'',
            shipToCountry:'',
            compoundId:'',
            compoundName:'',
            moleculeType:'',
            PhaseofDevelopment:'',
            EHSRequirements:'',
            GMPRequirements:'',
            RegulatoryClass:'',
            QuoteDueToClient:'',
            quoteId:'',
            quoteName:''         
        }
        this.compoundBoolean = {
            "create" : false, "update" :false};
        this.connectedCallback();
    }

    saveOpportunity(event){ 
        console.log('saving opportunity ...');
        event.preventDefault();
        const fields = event.detail.fields;
        this.oppObj.Name=fields.Name;
        this.oppObj.StageName=fields.StageName;
        this.oppObj.CloseDate=fields.CloseDate;
        this.oppObj.Type=fields.Type;
        this.oppObj.AccountId=fields.AccountId;
        this.oppObj.Requesting_User__c=this.requestingUser[0];//fields.Requesting_User__c;
        this.oppObj.Bypass_Reason__c=this.byPassReason;//fields.Bypass_Reason__c;
        this.oppObj.Background_Comments__c=fields.Background_Comments__c;
        this.oppObj.Due_Date_for_China__c=fields.Due_Date_for_China__c;
        console.log('this.oppObj.Due_Date_for_China__c '+this.oppObj.Due_Date_for_China__c);
        this.oppObj.Date_RFP_due_to_Client__c=fields.Date_RFP_due_to_Client__c;
        console.log('this.oppObj.Date_RFP_due_to_Client__c '+this.oppObj.Date_RFP_due_to_Client__c);
        this.oppObj.Ship_to_Country__c = fields.Ship_to_Country__c;
        saveOpportunityRecord({ oppObjstr: JSON.stringify(this.oppObj) })  
        .then((result) => {  
        if (result!=null) {             
            const evt = new ShowToastEvent({
                title: 'Success',
                message: 'Opportunity Saved Succesfully',
                variant: 'success'
            });
            this.dispatchEvent(evt);
        } 
        this.error = undefined;  
        //enable upload attachment model
        this.oppObj.Id=result.Id;        
        //this.oppObj.Disabled=true;
        this.compoundObj.Opportunity__c=this.oppObj.Id;
        this.quoteObj.OpportunityId=this.oppObj.Id;
        this.quoteObj.Name=this.oppObj.Name;
        this.quoteObj.Description__c=this.oppObj.Background_Comments__c;
        this.oppObj.FileUploadDisabled=false;      
        this.oppObj.NextButtonDisabled=false;            
        //Set Email details
        this.emailFeatureSettings.description=this.oppObj.Background_Comments__c;
        this.emailFeatureSettings.accountId=result.AccountId;
        this.emailFeatureSettings.accountName=result.Account.Name != undefined && result.Account.Name != null ?result.Account.Name : '';
        this.emailFeatureSettings.From=result.CreatedBy.Email;
        this.emailFeatureSettings.opportunityId=result.Id;
        this.emailFeatureSettings.opportunityName=result.Name;
        this.emailFeatureSettings.opportunityCreatedBy=result.CreatedBy.Name;
        this.emailFeatureSettings.dueDateForChina=result.Due_Date_for_China__c;
         this.emailFeatureSettings.shipToCountry=result.Ship_to_Country__c;
        })  
        .catch((error) => {  
       // this.error = error;  
        const evt = new ShowToastEvent({
            title: 'Error',
            message: error.body.message,
            variant: 'error'
        });
        this.dispatchEvent(evt);
    });         
    };

    handleOpportunityFilesUploadFinished(event){  
        const uploadedFiles = event.detail.files;    
        for(let oppattobj of uploadedFiles){
            this.opportunityAttachments.push(oppattobj);
        }  
        
        console.log('Opportunity File Upload::',JSON.stringify(uploadedFiles));
        //this.opportunityAttachments.concat(JSON.stringify(uploadedFiles));
      //   console.log('opportunityAttachments:'+JSON.stringify(this.opportunityAttachments));
        const evt = new ShowToastEvent({
            title: 'Success',
            message: 'Files uploaded opportunity successfully',
            variant: 'success'
        });
        this.dispatchEvent(evt);
    };

    handleCompoundFilesUploadFinished(event){  
        const uploadedFiles = event.detail.files;
        for(let compattobj of uploadedFiles){
            this.compoundAttachments.push(compattobj);
        }  

       // this.compoundAttachments.concat(uploadedFiles);   

        const evt = new ShowToastEvent({
            title: 'Success',
            message: 'Files uploaded to compound successfully',
            variant: 'success'
        });
        this.dispatchEvent(evt);
        
        console.log('uploadedFiles:'+JSON.stringify(uploadedFiles));
    };

    handleQuoteFilesUploadFinished(event){   
        const uploadedFiles = event.detail.files;   
        for(let quoteattobj of uploadedFiles){
            this.quoteAttachments.push(quoteattobj);
        }  
       // this.quoteAttachments.concat(uploadedFiles);

        const evt = new ShowToastEvent({
            title: 'Success',
            message: 'Files uploaded to Quote success',
            variant: 'success'
        });
        this.dispatchEvent(evt);
        
        //console.log('uploadedFiles:'+JSON.stringify(uploadedFiles));
    };


    //compound object work starting here
    saveCompound(event){ 
        event.preventDefault();
        const fields = event.detail.fields;
        this.compoundObj.Name=fields.Name;
        this.compoundObj.Opportunity__c=fields.Opportunity__c;
        this.compoundObj.Molecule_Type__c=fields.Molecule_Type__c;
        this.compoundObj.Phase_of_Development__c=fields.Phase_of_Development__c;
        this.compoundObj.EH_S_Requirements__c=fields.EH_S_Requirements__c;
        this.compoundObj.Regulatory_Class__c=fields.Regulatory_Class__c;
        this.compoundObj.GMP_Requirements__c=fields.GMP_Requirements__c;
        this.compoundObj.Therapeutic_Area__c=fields.Therapeutic_Area__c;
        saveCompoundRecord({ compoundObjstr: JSON.stringify(JSON.parse(JSON.stringify(this.compoundObj))) })  
        .then((result) => {  
        if (result!=null) {             
            const evt = new ShowToastEvent({
                title: 'Success',
                message: 'Compound Saved Succesfully',
                variant: 'success'
            });
            this.dispatchEvent(evt);
        } 
        this.error = undefined;  
        //enable upload attachment model
        this.compoundObj.Id=result.Id;     
        this.emailFeatureSettings.compoundId=this.compoundObj.Id;
        this.emailFeatureSettings.compoundName=result.Name;
        this.emailFeatureSettings.moleculeType=result.Molecule_Type__c;
        this.emailFeatureSettings.PhaseofDevelopment=result.Phase_of_Development__c;
        this.emailFeatureSettings.EHSRequirements=result.EH_S_Requirements__c;
        this.emailFeatureSettings.GMPRequirements=result.GMP_Requirements__c;
        this.emailFeatureSettings.RegulatoryClass=result.Regulatory_Class__c;
        //this.compoundObj.Disabled=true;
        this.compoundObj.FileUploadDisabled=false;     
        this.compoundObj.NextButtonDisabled=false;             
        })  
        .catch((error) => {  
       // this.error = error;  
        const evt = new ShowToastEvent({
            title: 'Error',
            message: error.body.message,
            variant: 'error'
        });
        this.dispatchEvent(evt);
    });       
    }

    //compound object work starting here
    saveExistingCompound(event){ 
        console.log('Submit Compound Name::',JSON.stringify(event.detail.fields));
        event.preventDefault();
        const fields = event.detail.fields;
        this.compoundObj.Name=fields.Name;
        this.compoundObj.Opportunity__c=fields.Opportunity__c;
        this.compoundObj.Product_Class__c=fields.Product_Class__c;
        
        saveExistingCompoundRecord({ compoundId: fields.Compound__c, opportunityId : fields.Opportunity__c,productClass : fields.Product_Class__c })  
        .then((result) => {  
        if (result!=null) {             
            const evt = new ShowToastEvent({
                title: 'Success',
                message: 'Compound Saved Succesfully',
                variant: 'success'
            });
            this.dispatchEvent(evt);
        } 
        this.error = undefined;  
        //enable upload attachment model
        this.compoundObj.Id='';
        this.compoundObj.Name = ''; 
        for(var i in result.opportuityCompoundRecs){
            if(result.opportuityCompoundRecs[i].Opportunity__c){
                result.opportuityCompoundRecs[i].OpportunityName = result.opportuityCompoundRecs[i].Opportunity__r.Name;
            }
            if(result.opportuityCompoundRecs[i].Compound__c){
                result.opportuityCompoundRecs[i].CompoundName = result.opportuityCompoundRecs[i].Compound__r.Name;
            }
        }
        this.emailFeatureSettings.isExistingCompound=true;
        this.compoundAttachments = result.fileRecs != undefined && result.fileRecs != null ? result.fileRecs : [] ;
        this.existingCompoundRecords = result.opportuityCompoundRecs != undefined && result.opportuityCompoundRecs != null ? result.opportuityCompoundRecs : []; 
        // this.compoundObj.Disabled=true;
        //Keep it as false.
        this.compoundObj.Disabled=false;
        this.compoundObj.FileUploadDisabled=false;     
        this.compoundObj.NextButtonDisabled=false;             
        })  
        .catch((error) => {  
       // this.error = error;  
        const evt = new ShowToastEvent({
            title: 'Error',
            message: error.body.message,
            variant: 'error'
        });
        this.dispatchEvent(evt);
    });      
    }

    handleSuccess(event) {    
    }

    //quote object work starting here
    saveQuote(event){ 
        event.preventDefault();
        const fields = event.detail.fields;
        this.quoteObj.Name=fields.Name;
        this.quoteObj.OpportunityId=fields.OpportunityId;
        this.quoteObj.Use_of_Product__c=fields.Use_of_Product__c;
        this.quoteObj.Scope_of_Work__c=fields.Scope_of_Work__c;
        this.quoteObj.Materials_Provided_by_Client__c=fields.Materials_Provided_by_Client__c;
        this.quoteObj.Description__c=fields.Description__c;
        this.quoteObj.Quote_due_to_Client__c=fields.Quote_due_to_Client__c;
        saveQuoteRecord({ quoteObjstr: JSON.stringify(JSON.parse(JSON.stringify(this.quoteObj))) })  
        .then((result) => {  
        if (result!=null) {             
            const evt = new ShowToastEvent({
                title: 'Success',
                message: 'Quote Saved Succesfully',
                variant: 'success'
            });
            this.dispatchEvent(evt);
        } 
        this.error = undefined;  
        this.emailFeatureSettings.quoteId=result.Id;
        this.emailFeatureSettings.quoteName=result.Name;
        
        this.emailFeatureSettings.QuoteDueToClient=result.Quote_due_to_Client__c;
        //enable upload attachment model
        this.quoteObj.Id=result.Id;    
        //this.quoteObj.Disabled=true;
        this.quoteObj.FileUploadDisabled=false;     
        this.quoteObj.NextButtonDisabled=false;             
        })  
        .catch((error) => {  
       // this.error = error;  
        const evt = new ShowToastEvent({
            title: 'Error',
            message: error.body.message,
            variant: 'error'
        });
        this.dispatchEvent(evt);
    });       
    }

    setFromAddress(event){
        this.emailFeatureSettings.From=event.target.value;
    }

    setToAddress(event){
        this.emailFeatureSettings.To=event.target.value;
    }

    setCCAddress(event){
        this.emailFeatureSettings.CC=event.target.value;
    }

    selectAttachment(event){
       // let data=this.emailFeatureSettings.selectAttachment;
       // data.push(event.target.value);
        this.emailFeatureSettings.SelectedAttachmentIds.push(event.target.value);
      //  console.log('emailFeatureSettings:'+JSON.stringify(this.emailFeatureSettings));
    }

    sendEmailWithAttachments(){
        console.log('emailFeatureSettings:'+JSON.stringify(this.emailFeatureSettings));
        sendemail({pemailsettings:JSON.stringify(this.emailFeatureSettings)})  
        .then((result) => {  
                
            const evt = new ShowToastEvent({
                title: 'Success',
                message: 'Email Sent Succesfully',
                variant: 'success'
            });
            this.dispatchEvent(evt);
            this.navigateToOpportunityRecord();
            this.refreshComponent();
            this.isModalOpen=false;
            this.error = undefined;    
        })  
        .catch((error) => {  
       // this.error = error;  
        const evt = new ShowToastEvent({
            title: 'Error',
            message: error.body.message,
            variant: 'error'
        });
        this.dispatchEvent(evt);
    });   
    }

    navigateToOpportunityRecord() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.emailFeatureSettings.opportunityId,
                objectApiName: 'Opportunity',
                actionName: 'view'
            }
        });
    }
    selectCompound(event){      
         this.compoundObj.SelectedCompoundIds.push(event.target.value);
     }

}