import { LightningElement, wire, track ,api} from 'lwc';
import getRelatedAccounts from '@salesforce/apex/AccountController.getRelatedAccounts';



const ACCOUNT_COLUMNS = [
    { label: 'Name', fieldName: 'accLink', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' }, sortable: true },
    { label: 'Industry', fieldName: 'Industry', type: 'text' },
    { label: 'Phone', fieldName: 'Phone', type: 'phone' },
    { label: 'Website', fieldName: 'Website', type: 'url' }
];

const ACCOUNT_CATALOG_COLUMNS = [
    { label: 'Name', fieldName: 'accLink', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' }, sortable: true },
];

export default class AccountTable extends LightningElement {
    @track accountData;
    @track accountColumns;
    @api recordId;
    
   title="Affiliated Records"
    iconname;
    isShow=false;
 connectedCallback() {
        // Use the getRecord method to retrieve the record's object type
        const recordIdString = this.recordId.toString();
        const firstThreeCharacters = recordIdString.substring(0, 3);
        if(firstThreeCharacters=='001'){
            this.title="Affiliated Accounts";
                this.iconname="standard:account";
        }
        else{
            this.title="Affiliated Account Catalog";
            this.iconname="standard:knowledge";
        }
        
    }    
    @wire(getRelatedAccounts, { parentId: '$recordId' })
    wiredRelatedAccounts({ error, data }) {
        
        if (data) {
            this.isShow=true;
            data = JSON.parse(JSON.stringify(data));
            data.forEach(res => {
                                res.accLink =  '/' + res.Id;
                                
                            });
            this.accountData = data;
            if(data[0].Id.startsWith('001')){
                this.title="Affiliated Accounts";
                this.iconname="standard:account";
                this.accountColumns = ACCOUNT_COLUMNS;
            }
            else{
               this.title="Affiliated Account Catalog";
                this.iconname="standard:knowledge";
                this.accountColumns = ACCOUNT_CATALOG_COLUMNS;
            }
           // this.accountColumns = this.getAccountColumns(data[0]);
        } else if (error) {
            // Handle the error
        }
    }

    

   
}