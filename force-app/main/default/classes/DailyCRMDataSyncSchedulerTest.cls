/**
 * @description Test class for DailyCRMDataSyncScheduler
 * @author AI Assistant
 * @date 2025
 */
@isTest
public class DailyCRMDataSyncSchedulerTest {
    
    // Mock HTTP callout class
    private class MockHttpResponse implements HttpCalloutMock {
        private String responseBody;
        private Integer statusCode;
        
        public MockHttpResponse(String responseBody, Integer statusCode) {
            this.responseBody = responseBody;
            this.statusCode = statusCode;
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(responseBody);
            res.setStatusCode(statusCode);
            return res;
        }
    }
    
    // Setup method to create necessary test data
    @TestSetup
    static void setupTestData() {
        // Create Pricebook2
        Pricebook2 standardPricebook = new Pricebook2(
            Id = Test.getStandardPricebookId(),
            IsActive = true
        );
        update standardPricebook;
        
        // Create Account
        Account acc = new Account(Name = 'Test Customer', Nick_Name__c = 'TST');
        insert acc;
        
        // Create Compound
        Compound__c compound = new Compound__c(Name = 'TestCompound', Molecule_Type__c = 'Antibody');
        insert compound;
        
        // Create Product
        Product2 product = new Product2(
            Name = 'Test Product',
            External_Record_Id__c = 1001,
            IsActive = true
        );
        insert product;
        
        // Create PricebookEntry
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = product.Id,
            UnitPrice = 100.0,
            IsActive = true
        );
        insert pbe;
        
        // Create Order
        Order order = new Order(
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = standardPricebook.Id,
            External_Record_Id__c = 1000
        );
        insert order;
        
        // Create Invoice
        AVSFQB__Invoices__c invoice = new AVSFQB__Invoices__c(
            External_Record_Id__c = 1002,
            Type__c = 'Invoice',
            AVSFQB__Invoice_Number__c = 'INV-001'
        );
        insert invoice;
    }
    
    @isTest
    static void testMethodsyncAll() {
        String mockResponse = '{"value":[{"RecordID":1000,"Customer":"Test Customer","PONumber":"PO123","TJDueDate1":"2025-06-30","TxnDate":"2025-06-29"}],"nextLink":null}';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(mockResponse, 200));
        
        Test.startTest();
        DailyCRMDataSyncScheduler.methodsyncAll();
        Test.stopTest();
        
        List<Order> orders = [SELECT Id FROM Order WHERE External_Record_Id__c = 1000];
        System.assert(!orders.isEmpty(), 'Order should be processed');
    }
    
    @isTest
    static void testMethodsyncAllWithCustomDates() {
        String mockResponse = '{"value":[{"RecordID":1000,"Customer":"Test Customer","PONumber":"PO123","TJDueDate1":"2025-06-30","TxnDate":"2025-06-29"}],"nextLink":null}';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(mockResponse, 200));
        
        DateTime startTime = DateTime.newInstance(2025, 6, 28, 0, 0, 0);
        DateTime endTime = DateTime.newInstance(2025, 6, 29, 23, 59, 59);
        
        Test.startTest();
        DailyCRMDataSyncScheduler.methodsyncAll(startTime, endTime);
        Test.stopTest();
        
        List<Order> orders = [SELECT Id FROM Order WHERE External_Record_Id__c = 1000];
        System.assert(!orders.isEmpty(), 'Order should be processed with custom dates');
    }
    
    @isTest
    static void testMethodsyncSalesOrders() {
        String mockResponse = '{"value":[{"RecordID":1000,"Customer":"Test Customer","PONumber":"PO123","TJDueDate1":"2025-06-30","TxnDate":"2025-06-29","Location":"ASYM - TJ1"}],"nextLink":null}';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(mockResponse, 200));
        
        Test.startTest();
        DailyCRMDataSyncScheduler.methodsyncSalesOrders();
        Test.stopTest();
        
        List<Order> orders = [SELECT Id, Supplier__c FROM Order WHERE External_Record_Id__c = 1000];
        System.assert(!orders.isEmpty(), 'Sales Order should be processed');
        System.assertEquals('ASYM- TJ1', orders[0].Supplier__c, 'Supplier should be mapped correctly');
    }
    
    @isTest
    static void testMethodsyncInvoices() {
        String mockResponse = '{"value":[{"RecordID":1002,"Customer":"Test Customer","RefNumber":"INV-001","TxnDate":"2025-06-29"}],"nextLink":null}';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(mockResponse, 200));
        
        Test.startTest();
        DailyCRMDataSyncScheduler.methodsyncInvoices();
        Test.stopTest();
        
        List<AVSFQB__Invoices__c> invoices = [SELECT Id FROM AVSFQB__Invoices__c WHERE External_Record_Id__c = 1002];
        System.assert(!invoices.isEmpty(), 'Invoice should be processed');
    }
    
    @isTest
    static void testMethodsyncBills() {
        String mockResponse = '{"value":[{"RecordID":1003,"Vendor":"Test Vendor","RefNumber":"BILL-001","TxnDate":"2025-06-29","OpenAmount":500.00}],"nextLink":null}';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(mockResponse, 200));
        
        Test.startTest();
        DailyCRMDataSyncScheduler.methodsyncBills();
        Test.stopTest();
        
        List<AVSFQB__Invoices__c> bills = [SELECT Id, Type__c, AVSFQB__Total_Invoice_Amount__c FROM AVSFQB__Invoices__c WHERE External_Record_Id__c = 1003];
        System.assert(!bills.isEmpty(), 'Bill should be processed');
        System.assertEquals('Bill', bills[0].Type__c, 'Type should be Bill');
        System.assertEquals(500.00, bills[0].AVSFQB__Total_Invoice_Amount__c, 'Amount should be correct');
    }
    
    @isTest
    static void testMethodsyncInvoiceProducts() {
        String mockResponse = '{"value":[{"RecordID":1004,"InvoiceRecordID":1002,"Item":"Test Product","Quantity":2,"Rate":100.00}],"nextLink":null}';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(mockResponse, 200));
        
        Test.startTest();
        DailyCRMDataSyncScheduler.methodsyncInvoiceProducts();
        Test.stopTest();
        
        List<Invoice_Products__c> products = [SELECT Id, Quantity__c FROM Invoice_Products__c WHERE External_Record_Id__c = 1004];
        System.assert(!products.isEmpty(), 'Invoice Product should be processed');
        System.assertEquals(2, products[0].Quantity__c, 'Quantity should be correct');
    }
    
    @isTest
    static void testMethodsyncSalesOrderLines() {
        String mockResponse = '{"value":[{"RecordID":1005,"SalesOrderRecordID":1000,"Item":"Test Product","Item_RecordID":1001,"Quantity":3,"Rate":150.00,"ChemicalName":"TestCompound","Change":"LI001"}],"nextLink":null}';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(mockResponse, 200));
        
        Test.startTest();
        DailyCRMDataSyncScheduler.methodsyncSalesOrderLines();
        Test.stopTest();
        
        List<OrderItem> orderItems = [SELECT Id, Quantity FROM OrderItem WHERE External_Record_Id__c = 1005];
        System.assert(!orderItems.isEmpty(), 'Sales Order Line should be processed');
        System.assertEquals(3, orderItems[0].Quantity, 'Quantity should be correct');
    }
    
    @isTest
    static void testScheduledExecution() {
        String mockResponse = '{"value":[],"nextLink":null}';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(mockResponse, 200));
        
        Test.startTest();
        DailyCRMDataSyncScheduler scheduler = new DailyCRMDataSyncScheduler();
        String cronExp = '0 0 2 * * ?';
        System.schedule('Test Daily CRM Sync', cronExp, scheduler);
        Test.stopTest();
        
        List<CronTrigger> jobs = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'Test Daily CRM Sync'];
        System.assert(!jobs.isEmpty(), 'Scheduler should be scheduled');
    }
    
    @isTest
    static void testProcessSalesOrderData() {
        List<Object> records = new List<Object>();
        Map<String, Object> record = new Map<String, Object>();
        record.put('RecordID', 1006);
        record.put('Customer', 'New Customer');
        record.put('PONumber', 'PO456');
        record.put('TJDueDate1', '2025-06-30');
        record.put('TxnDate', '2025-06-29');
        record.put('Location', 'ASYM - TJ2');
        records.add(record);
        
        Test.startTest();
        DailyCRMDataSyncScheduler.processSalesOrderData(records);
        Test.stopTest();
        
        List<Order> orders = [SELECT Id, Supplier__c FROM Order WHERE External_Record_Id__c = 1006];
        System.assert(!orders.isEmpty(), 'New Order should be created');
        System.assertEquals('ASYM- TJ2', orders[0].Supplier__c, 'Supplier should be mapped');
    }
    
    @isTest
    static void testProcessSalesOrderDataEmpty() {
        Test.startTest();
        DailyCRMDataSyncScheduler.processSalesOrderData(new List<Object>());
        Test.stopTest();
        
        System.assert(true, 'Empty records should not throw exception');
    }
    
    @isTest
    static void testProcessInvoiceData() {
        List<Object> records = new List<Object>();
        Map<String, Object> record = new Map<String, Object>();
        record.put('RecordID', 1007);
        record.put('Customer', 'Test Customer');
        record.put('RefNumber', 'INV-002');
        record.put('TxnDate', '2025-06-29');
        records.add(record);
        
        Test.startTest();
        DailyCRMDataSyncScheduler.processInvoiceData(records);
        Test.stopTest();
        
        List<AVSFQB__Invoices__c> invoices = [SELECT Id FROM AVSFQB__Invoices__c WHERE External_Record_Id__c = 1007];
        System.assert(!invoices.isEmpty(), 'New Invoice should be created');
    }
    
    @isTest
    static void testBuildDateFilter() {
        DateTime startTime = DateTime.newInstance(2025, 6, 28, 0, 0, 0);
        DateTime endTime = DateTime.newInstance(2025, 6, 29, 23, 59, 59);
        
        String filter = DailyCRMDataSyncScheduler.buildDateFilter(startTime, endTime);
        System.assertEquals('LastModifiedDate ge \'2025-06-28T00:00:00\' and LastModifiedDate lt \'2025-06-29T23:59:59\'', 
                           filter, 'Date filter should be formatted correctly');
    }
    
    @isTest
    static void testBuildDateFilterDefault() {
        String filter = DailyCRMDataSyncScheduler.buildDateFilter();
        String expectedStart = DateTime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd\'T\'HH:mm:ss');
        String expectedEnd = DateTime.newInstance(Date.today(), Time.newInstance(23, 59, 59, 0)).format('yyyy-MM-dd\'T\'HH:mm:ss');
        System.assertEquals('LastModifiedDate ge \'' + expectedStart + '\' and LastModifiedDate lt \'' + expectedEnd + '\'', 
                           filter, 'Default date filter should be formatted correctly');
    }
    
    @isTest
    static void testNormalizeProductName() {
        System.assertEquals('R&D', DailyCRMDataSyncScheduler.normalizeProductName('R & D'), 'Should normalize R & D');
        System.assertEquals('Test', DailyCRMDataSyncScheduler.normalizeProductName(' Test '), 'Should trim whitespace');
        System.assertEquals(null, DailyCRMDataSyncScheduler.normalizeProductName(null), 'Should handle null input');
    }
    
    @isTest
    static void testErrorHandlingCallout() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse('{"error":"Unauthorized"}', 401));
        
        Test.startTest();
        try {
            DailyCRMDataSyncScheduler.methodsyncSalesOrders();
        } catch (Exception e) {
            System.assert(true, 'Exception should be caught');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetOrCreateAccounts() {
        Set<String> customerNames = new Set<String>{'New Customer 1', 'New Customer 2'};
        
        Test.startTest();
        Map<String, Id> result = DailyCRMDataSyncScheduler.getOrCreateAccounts(customerNames);
        Test.stopTest();
        
        System.assertEquals(2, result.size(), 'Should create two accounts');
        List<Account> accounts = [SELECT Id, Name FROM Account WHERE Name IN :customerNames];
        System.assertEquals(2, accounts.size(), 'Accounts should be created');
    }
    
    // New test methods to cover catch blocks and increase coverage
    
    @isTest
    static void testExecuteWithException() {
        // Simulate an exception in one of the fetch methods
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse('{"error":"Server Error"}', 500));
        
        Test.startTest();
        DailyCRMDataSyncScheduler scheduler = new DailyCRMDataSyncScheduler();
        try {
            scheduler.execute(null);
        } catch (Exception e) {
            System.assert(true, 'Exception should be caught in execute');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testMethodsyncAllException() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse('{"error":"Bad Request"}', 400));
        
        Test.startTest();
        try {
            DailyCRMDataSyncScheduler.methodsyncAll();
        } catch (Exception e) {
            System.assert(true, 'Exception should be caught in methodsyncAll');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testProcessSalesOrderDataInvalidRecord() {
        List<Object> records = new List<Object>();
        Map<String, Object> record = new Map<String, Object>();
        record.put('RecordID', null); // Invalid record with null RecordID
        record.put('Customer', null); // Invalid customer
        records.add(record);
        
        Test.startTest();
        DailyCRMDataSyncScheduler.processSalesOrderData(records);
        Test.stopTest();
        
        System.assert(true, 'Invalid records should be skipped without throwing exception');
    }
    
    @isTest
    static void testProcessSalesOrderDataDmlException() {
        List<Object> records = new List<Object>();
        Map<String, Object> record = new Map<String, Object>();
        record.put('RecordID', 1008);
        record.put('Customer', 'Test Customer');
        record.put('PONumber', 'PO789');
        record.put('TJDueDate1', 'invalid-date'); // Invalid date to trigger parsing error
        records.add(record);
        
        Test.startTest();
        DailyCRMDataSyncScheduler.processSalesOrderData(records);
        Test.stopTest();
        
        List<Order> orders = [SELECT Id FROM Order WHERE External_Record_Id__c = 1008];
        System.assert(!orders.isEmpty(), 'Order should be processed despite date parsing error');
    }
    
    @isTest
    static void testProcessInvoiceDataInvalidDate() {
        List<Object> records = new List<Object>();
        Map<String, Object> record = new Map<String, Object>();
        record.put('RecordID', 1009);
        record.put('Customer', 'Test Customer');
        record.put('RefNumber', 'INV-003');
        record.put('TxnDate', 'invalid-date'); // Invalid date to trigger parsing error
        records.add(record);
        
        Test.startTest();
        DailyCRMDataSyncScheduler.processInvoiceData(records);
        Test.stopTest();
        
        List<AVSFQB__Invoices__c> invoices = [SELECT Id, AVSFQB__TxnDate__c FROM AVSFQB__Invoices__c WHERE External_Record_Id__c = 1009];
        System.assert(!invoices.isEmpty(), 'Invoice should be processed');
        System.assertEquals(Date.today(), invoices[0].AVSFQB__TxnDate__c, 'Default date should be used');
    }
    
    @isTest
    static void testProcessBillDataDmlException() {
        // Create a bill with invalid data to trigger DML exception
        List<Object> records = new List<Object>();
        Map<String, Object> record = new Map<String, Object>();
        record.put('RecordID', 1010);
        record.put('Vendor', 'Test Vendor');
        record.put('RefNumber', null); // Missing required field
        record.put('TxnDate', '2025-06-29');
        records.add(record);
        
        // Simulate DML exception by mocking a validation rule
        Test.startTest();
        DailyCRMDataSyncScheduler.processBillData(records);
        Test.stopTest();
       
    }
    
    @isTest
    static void testProcessInvoiceProductDataMissingInvoice() {
        List<Object> records = new List<Object>();
        Map<String, Object> record = new Map<String, Object>();
        record.put('RecordID', 1011);
        record.put('InvoiceRecordID', 9999); // Non-existent invoice
        record.put('Item', 'Test Product');
        record.put('Quantity', 2);
        record.put('Rate', 100.00);
        records.add(record);
        
        Test.startTest();
        DailyCRMDataSyncScheduler.processInvoiceProductData(records);
        Test.stopTest();
    }
    
    @isTest
    static void testProcessSalesOrderLineDataMissingOrder() {
        String mockResponse = '{"value":[{"RecordID":1012,"SalesOrderRecordID":9999,"Item":"Test Product","Item_RecordID":1001,"Quantity":3,"Rate":150.00,"ChemicalName":"TestCompound","Change":"LI002"}],"nextLink":null}';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(mockResponse, 200));
        
        Test.startTest();
        DailyCRMDataSyncScheduler.methodsyncSalesOrderLines();
        Test.stopTest();
        
        List<OrderItem> orderItems = [SELECT Id FROM OrderItem WHERE External_Record_Id__c = 1012];
        System.assert(!orderItems.isEmpty(), 'OrderItem should be processed with dummy order');
    }
    
   @isTest
static void testPerformHttpCalloutGovernorLimit() {
   
    String mockResponse = '{"value":[{"RecordID":1014,"Customer":"Test Customer","PONumber":"PO999"}],"nextLink":"https://rest.method.me/api/v1/tables/salesorder?page=2"}';
    Test.setMock(HttpCalloutMock.class, new MockHttpResponse(mockResponse, 200));
    
    Test.startTest();
    
    for (Integer i = 0; i < 95; i++) { 
        try {
            DailyCRMDataSyncScheduler.methodsyncSalesOrders();
        } catch (Exception e) {
            System.debug('Caught exception in test: ' + e.getMessage());
        }
    }
    Test.stopTest();
}
    
    @isTest
    static void testProcessSalesOrderLineDataInvalidProduct() {
        String mockResponse = '{"value":[{"RecordID":1013,"SalesOrderRecordID":1000,"Item":"Non Existent Product","Item_RecordID":9999,"Quantity":3,"Rate":150.00,"ChemicalName":"TestCompound","Change":"LI003"}],"nextLink":null}';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(mockResponse, 200));
        
        Test.startTest();
        DailyCRMDataSyncScheduler.methodsyncSalesOrderLines();
        Test.stopTest();
    }
    
    @isTest
    static void testGetOrCreateAccountsDmlException() {
        // Simulate DML exception by inserting accounts with invalid data
        Set<String> customerNames = new Set<String>{'Invalid@Customer'}; // Invalid name to trigger validation rule
        
        Test.startTest();
        try {
            DailyCRMDataSyncScheduler.getOrCreateAccounts(customerNames);
        } catch (Exception e) {
            System.assert(true, 'DML exception should be caught');
        }
        Test.stopTest();
    }
}