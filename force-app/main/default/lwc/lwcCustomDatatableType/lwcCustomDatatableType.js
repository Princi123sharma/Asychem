import LightningDatatable from 'lightning/datatable';
import picklistColumn from './picklistColumn.html';
import picklistAccess from './picklistAccess.html';
import pickliststatic from './pickliststatic.html';
import pickliststatic1 from './pickliststatic1.html';

export default class LWCCustomDatatableType extends LightningDatatable {
    static customTypes = {
        picklistColumn: {
            template: pickliststatic,
            editTemplate: picklistColumn,
            standardCellLayout: true,
            typeAttributes: ['label', 'placeholder', 'options', 'value', 'context', 'variant','name']
        },
    };
    static customTypes1 = {
        picklistAccess: {
            template: pickliststatic1,
            editTemplate: picklistAccess,
            standardCellLayout: true,
            typeAttributes: ['label', 'placeholder', 'options', 'value', 'context', 'variant','name']
        },
    };
}