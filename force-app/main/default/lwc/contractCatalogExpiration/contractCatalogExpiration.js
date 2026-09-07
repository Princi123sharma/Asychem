import { LightningElement, track, wire  } from 'lwc';
import getContract from '@salesforce/apex/ContractCatalogExpirationController.getContract';
export default class contractCatalogExpiration extends LightningElement {
    @track months = '3';
    @track contractType = 'MyContract';
    @track contractCatalog;
    @track isLoaded = false;
    options = [
        { label: '3 Months', value: '3' },
        { label: '6 Months', value: '6' }
    ];
    contractOptions = [
        { label: 'My Contract', value: 'MyContract' },
        { label: 'All Contract', value: 'AllContract' }
    ];
    columns = [
        { label: 'Contract', fieldName: 'Contract_ID__c' , type: 'url',
                    typeAttributes: { label: { fieldName: 'Name' }, target: '_blank'}},
        { label: 'Account', fieldName: 'Account_Catalog__c', type: 'url',
                    typeAttributes: { label: { fieldName: 'Account_Name__c' }, target: '_blank'} },
        { label: 'Type', fieldName: 'Type_of_Contract__c'},
        { label: 'Expiration Date', fieldName: 'EndDate__c', type: 'date' },
        { label: 'Owner', fieldName: 'Account_Owner__c' }
    ];
    connectedCallback() {
        this.loadData();
    }
    @wire( getContract )
        loadData() {
            console.log(' this.contractType ' +  this.contractType);
            console.log(' this.months ' +  this.months);
            getContract({ months: this.months ,
                                          contractType: this.contractType })
            .then(result => {
                console.log('result ' + JSON.stringify(result));
                if ( result ) {
                    let tempRecs = [];
                    result.forEach( ( record ) => {
                    let tempRec = Object.assign( {}, record );
                    tempRec.Contract_ID__c = '/lightning/r/Contract/' + tempRec.Id +'/view';
                    tempRec.Account_Catalog__c = '/lightning/r/Account/' + tempRec.Account_Catalog__c +'/view';
                    tempRecs.push( tempRec );
                });
            this.contractCatalog = tempRecs;
            this.error = undefined;
        } else if ( error ) {
            this.error = error;
            this.contractCatalog = undefined;
        }
        });
    }
    handleMonthsChange(event) {
        this.months = event.target.value;
        this.loadData();
    }
    handleContractTypeChange(event) {
        this.contractType = event.target.value;
        this.loadData();
    }
}