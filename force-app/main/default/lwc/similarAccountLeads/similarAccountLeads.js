import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import findSimilarLeads from '@salesforce/apex/similarAccLeadController.findSimilarLeads';


const columns = [
    { label: 'Name', fieldName: 'Name' },
    { label: 'Company', fieldName: 'Company', type: 'text' },
    //{ label: 'Email', fieldName: 'Email', type: 'email' },
    //{ label: 'Phone', fieldName: 'Phone', type: 'phone' }
];

export default class SimilarLeads extends LightningElement {
    @api recordId;
    @track similarLeads;

    @wire(getRecord, { recordId: '$recordId', fields: ['Lead_Catalog__c.Lead_Company__c','Lead_Catalog__c.Lead__c'] })
    lead;

    @wire(findSimilarLeads, { leadId: '$lead.data.fields.Lead__c.value', companyName: '$lead.data.fields.Lead_Company__c.value' })
    wiredLeads({ error, data }) {
        if (data) {
            this.similarLeads = data;
        } else if (error) {
            console.error(error);
        }
    }

    get columns() {
        return columns;
    }
}