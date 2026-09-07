@isTest
private class ContractCatalogExpirationControllerTest {
	 @isTest
    static void testgetExpiringContractsCatalog() {
        // Setup test data
        Account testAccount = new Account(Name = 'Test Account',Nick_Name__c = 'Test Account');
        insert testAccount;
        
        Account_Catalog__c testAccountCatalog = new Account_Catalog__c(Account__c = testAccount.Id);
        insert testAccountCatalog;
        
        Contract testContract = new Contract(Name = 'Test Contract',Startdate = system.today(), AccountId = testAccount.Id );
        insert testContract;
        
        Contract_Catalog__c testContractCatalog = new Contract_Catalog__c(Name = 'Test Contract Catalog',
                                                                          Account_Catalog__c = testAccountCatalog.Id );
        insert testContractCatalog;
        
          // call the getExpiringContractsCatalog method
        List<Contract_Catalog__c> contracts = ContractCatalogExpirationController.getContract(3,'MyContract');
        List<Contract_Catalog__c> contracts2 = ContractCatalogExpirationController.getContract(3,'AllContract');
    }
}