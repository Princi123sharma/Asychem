@isTest
public class AccountControllerTest {
    @isTest
    static void testGetRelatedAccounts() {
        // Create test data
        Account parentAccount = new Account(Name='Parent Account',Nick_Name__c='test1', Industry='Technology', Phone='(555) 123-4567', Website='https://www.example.com',ParentId=null);
        insert parentAccount;
        
        Account childAccount1 = new Account(Name='Child Account 1',Nick_Name__c='test2', Industry='Finance', Phone='(555) 123-4568', Website='https://www.example1.com', ParentId=parentAccount.Id);
        insert childAccount1;
        
        Account childAccount2 = new Account(Name='Child Account 2',Nick_Name__c='test3', Industry='Manufacturing', Phone='(555) 123-4569', Website='https://www.example2.com', ParentId=parentAccount.Id);
        insert childAccount2;
        
        Account_Catalog__c accountCatalog = new Account_Catalog__c(Name='Parent Account',Account__c=parentAccount.Id);
        insert accountCatalog;
        Account_Catalog__c accountCatalog2 = new Account_Catalog__c(Name='Child Account 1',Account__c=childAccount1.Id,Parent_Account_Catalog__c=accountCatalog.Id);
        insert accountCatalog2;
        Account_Catalog__c accountCatalog3 = new Account_Catalog__c(Name='Child Account 2',Account__c=childAccount2.Id,Parent_Account_Catalog__c=accountCatalog.Id);
        insert accountCatalog3;
        // Test method for Account object
        
        
        List<Account> relatedAccounts = AccountController.getRelatedAccounts(childAccount1.Id);
        
        List<Account_Catalog__c> relatedAccountsCatalog = AccountController.getRelatedAccounts(accountCatalog2.Id);
       
        System.assertEquals(2,relatedAccounts.size());
        System.assertEquals(2, relatedAccountsCatalog.size()); 
    }
}