import { LightningElement, api, wire } from 'lwc';
import getOpportunityCounts from '@salesforce/apex/OpenOpportunitiesCounter.fetchOpportunityCounts'; 


export default class OpportunityCount extends LightningElement {
    @api recordId;
    openOpportunitiesCount = 0;
    closedOpportunitiesCount = 0;


    @wire(getOpportunityCounts, { accountCatalogueId: '$recordId' })
    wiredOpportunityCount({ error, data }) {
        if (data) {
            console.log('data ' + JSON.stringify(data));
            this.openOpportunitiesCount = data.openOppsCount;
            this.closedOpportunitiesCount = data.closedOppsCount;
        } else if (error) {
        }
    }
}