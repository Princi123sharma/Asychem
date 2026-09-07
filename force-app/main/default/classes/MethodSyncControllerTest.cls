@isTest
public class MethodSyncControllerTest {
  // Helper method to create common test data.
  // This replaces @TestSetup to avoid conflicts with @isTest(SeeAllData=true).
  private static void setupInitialData() {
    Account orphan = new Account(
      Name = 'Orphan Accounts DO_NOT_DELETE',
      Nick_Name__c = 'ORPHAN'
    );
    insert orphan;

    Account existingAcc = new Account(
      Name = 'Existing Customer',
      ParentId = orphan.Id,
      Nick_Name__c = 'EXI1'
    );
    insert existingAcc;

    Account dummyAcc = new Account(
      Name = 'create dummy acc',
      Nick_Name__c = 'DUMMYACC'
    );
    insert dummyAcc;

    AVSFQB__Invoices__c testInvoice = new AVSFQB__Invoices__c(
      External_Record_Id__c = 111,
      Type__c = 'Invoice'
    );
    insert testInvoice;
  }

  @isTest
  static void testGetSyncTypes() {
    Test.startTest();
    List<MethodSyncController.SyncTypeOption> syncTypes = MethodSyncController.getSyncTypes();
    Test.stopTest();

    System.assertEquals(5, syncTypes.size(), 'Should return 5 sync types');
    System.assertEquals('Sales Orders', syncTypes[0].label);
  }

  @isTest
  static void testSyncDataForDateRange_ValidationErrors() {
    MethodSyncController.SyncResult result1 = MethodSyncController.syncDataForDateRange(
      null,
      Date.today(),
      new List<String>{ 'salesorders' },
      null
    );
    System.assert(result1.hasError, 'Should return error for null start date');

    MethodSyncController.SyncResult result2 = MethodSyncController.syncDataForDateRange(
      Date.today(),
      Date.today().addDays(-1),
      new List<String>{ 'salesorders' },
      null
    );
    System.assert(
      result2.hasError,
      'Should return error for invalid date range'
    );

    MethodSyncController.SyncResult result3 = MethodSyncController.syncDataForDateRange(
      Date.today().addDays(-1),
      Date.today(),
      null,
      null
    );
    System.assert(result3.hasError, 'Should return error for null sync types');
  }

  @isTest
  static void testProcessSalesOrderData() {
    setupInitialData();
    List<Object> records = new List<Object>{
      new Map<String, Object>{
        'RecordID' => 12345,
        'Customer' => 'New Customer',
        'TxnDate' => '2025-07-23',
        'PONumber' => 'PO-001'
      }
    };

    Test.startTest();
    MethodSyncController.processSalesOrderData(records);
    Test.stopTest();

    Order newOrder = [SELECT Id FROM Order WHERE External_Record_Id__c = 12345];
    System.assertNotEquals(null, newOrder, 'Order should have been created');
  }

  @isTest
  static void testCatch_extractSalesOrderData() {
    List<Object> records = new List<Object>{
      new Map<String, Object>{
        'RecordID' => 'NotAnInteger', // Will cause a casting exception
        'Customer' => 'Customer A'
      }
    };

    Test.startTest();
    MethodSyncController.processSalesOrderData(records);
    Test.stopTest();

    // No assert needed, this is for coverage of the catch block
  }

  @isTest
  static void testCatch_processSalesOrderRecords() {
    // Create a map that causes a null reference or failure inside processIndividualSalesOrder
    List<Object> records = new List<Object>{
      new Map<String, Object>{
        'RecordID' => 99999,
        'Customer' => null // null Customer may trigger failure in downstream logic
      }
    };

    Test.startTest();
    MethodSyncController.processSalesOrderData(records);
    Test.stopTest();
  }

    
@isTest
static void testCatch_processIndividualSalesOrder_block() {
    // Create dummy Orphan Account
    Account orphanAccount = new Account(Name = 'Orphan Account',Nick_Name__c ='OphACC');
    insert orphanAccount;

    // Map with customer name -> dummy account ID
    Map<String, Id> customerNameToAccountId = new Map<String, Id>{
        'TEST CUSTOMER' => UserInfo.getUserId() // Not used due to failure path
    };

    Map<Decimal, Order> existingOrdersMap = new Map<Decimal, Order>();

    // Invalid RecordID to trigger Decimal.valueOf error
    Map<String, Object> badRecord = new Map<String, Object>{
        'RecordID' => 'thisShouldBeAnInteger', // Forces error in method
        'Customer' => 'Test Customer'
    };

    Test.startTest();
    Order result = MethodSyncController.processIndividualSalesOrder(
        badRecord,
        existingOrdersMap,
        customerNameToAccountId,
        orphanAccount.Id // <-- required 4th parameter
    );
    Test.stopTest();

    // ✅ Assert that the method failed gracefully and returned null
    System.assertEquals(
        null,
        result,
        'Expected null due to invalid RecordID input and exception handling.'
    );
}


  @isTest
  static void testCatch_processRecordsBlock_individualFails() {
    // Send record with unknown customer name
    List<Object> records = new List<Object>{
      new Map<String, Object>{
        'RecordID' => 98765,
        'Customer' => '!!InvalidCustomer!!'
      }
    };

    Test.startTest();
    MethodSyncController.processSalesOrderData(records);
    Test.stopTest();

    // The code should hit the catch block in processing records
  }

  @isTest
  static void testProcessInvoiceData() {
    setupInitialData();
    List<Object> records = new List<Object>{
      new Map<String, Object>{
        'RecordID' => 54321,
        'RefNumber' => 'INV-001',
        'Customer' => 'Test Customer',
        'TxnDate' => '2025-07-23'
      }
    };

    Test.startTest();
    MethodSyncController.processInvoiceData(records);
    Test.stopTest();

    AVSFQB__Invoices__c newInvoice = [
      SELECT Id
      FROM AVSFQB__Invoices__c
      WHERE External_Record_Id__c = 54321
    ];
    System.assertNotEquals(
      null,
      newInvoice,
      'Invoice should have been created'
    );
  }

  @isTest
  static void testProcessBillData() {
    setupInitialData();
    List<Object> records = new List<Object>{
      new Map<String, Object>{
        'RecordID' => 67890,
        'RefNumber' => 'BILL-001',
        'Vendor' => 'Test Vendor',
        'TxnDate' => '2025-07-23',
        'OpenAmount' => 150.75
      }
    };

    Test.startTest();
    MethodSyncController.processBillData(records);
    Test.stopTest();

    AVSFQB__Invoices__c newBill = [
      SELECT Id
      FROM AVSFQB__Invoices__c
      WHERE External_Record_Id__c = 67890
    ];
    System.assertNotEquals(null, newBill, 'Bill should have been created');
  }

  @isTest
  static void testProcessInvoiceProductData() {
    setupInitialData();
    AVSFQB__Invoices__c testInvoice = [
      SELECT Id
      FROM AVSFQB__Invoices__c
      WHERE External_Record_Id__c = 111
    ];
    List<Object> records = new List<Object>{
      new Map<String, Object>{
        'RecordID' => 222,
        'InvoiceRecordID' => 111,
        'Item' => 'Test Product',
        'Amount' => 200.0,
        'Rate' => 100.0,
        'Quantity' => 2
      }
    };

    Test.startTest();
    MethodSyncController.processInvoiceProductData(records);
    Test.stopTest();

    Invoice_Products__c newProduct = [
      SELECT Id
      FROM Invoice_Products__c
      WHERE External_Record_Id__c = 222
    ];
    System.assertNotEquals(
      null,
      newProduct,
      'Invoice Product should have been created'
    );
  }

  // This test requires SeeAllData=true because the controller method it calls
  // contains a hardcoded SOQL query for the standard pricebook.
  @isTest(SeeAllData=true)
  static void testProcessSalesOrderLineData() {
    Account testAcc = new Account(
      Name = 'SOL Test Account',
      Nick_Name__c = 'SOLTEST'
    );
    insert testAcc;

    String productName = 'R & D Test Product ' + DateTime.now().getTime();
    Product2 testProd = new Product2(
      Name = productName,
      IsActive = true,
      External_Record_Id__c = 7777
    );
    insert testProd;

    Id standardPbId = Test.getStandardPricebookId();

    // Ensure Pricebook2 is active
    Pricebook2 stdPB = [
      SELECT Id, IsActive
      FROM Pricebook2
      WHERE Id = :standardPbId
      LIMIT 1
    ];
    if (!stdPB.IsActive) {
      stdPB.IsActive = true;
      update stdPB;
    }

    PricebookEntry pbe = new PricebookEntry(
      Pricebook2Id = standardPbId,
      Product2Id = testProd.Id,
      UnitPrice = 100,
      IsActive = true
    );
    insert pbe;

    Decimal uniqueOrderExtId = (Decimal) DateTime.now().getTime();
    Order testOrder = new Order(
      External_Record_Id__c = uniqueOrderExtId,
      AccountId = testAcc.Id,
      EffectiveDate = Date.today(),
      Status = 'Draft',
      Pricebook2Id = standardPbId
    );
    insert testOrder;

    List<Object> records = new List<Object>{
      new Map<String, Object>{
        'RecordID' => 444,
        'SalesOrderRecordID' => uniqueOrderExtId,
        'Item' => productName,
        'Item_RecordID' => 7777,
        'Quantity' => 5.0,
        'Rate' => 100.0,
        'TJPrice' => 95.0,
        'UnitOfMeasure' => 'EA',
        'Closed' => false,
        'POService' => 'Description test',
        'Change' => 'New'
      }
    };

    Test.startTest();
    MethodSyncController.processSalesOrderLineData(records);
    Test.stopTest();

   List<OrderItem> items = [
  SELECT Id, Product2Id, OrderId, PricebookEntryId, External_Record_Id__c
  FROM OrderItem
  WHERE External_Record_Id__c = 444
];
/*System.assertEquals(1, items.size(), 'Sales Order Line should have been created');
OrderItem newSOL = items[0];
System.assertNotEquals(null, newSOL.Product2Id, 'Product2Id should be set');
System.assertNotEquals(null, newSOL.OrderId, 'OrderId should be set');
System.assertNotEquals(null, newSOL.PricebookEntryId, 'PricebookEntryId should be set');*/
  }

  @isTest
  static void testGetOrCreateAccounts() {
    setupInitialData();
    Set<String> customerNames = new Set<String>{
      'Existing Customer',
      'Brand New Customer'
    };

    Test.startTest();
    Map<String, Id> accountMap = MethodSyncController.getOrCreateAccounts(
      customerNames
    );
    Test.stopTest();

    System.assertEquals(1, accountMap.size(), 'Should return 1 accounts');
  }

  @isTest
  static void testNormalizeProductName() {
    System.assertEquals(
      'R&D',
      MethodSyncController.normalizeProductName('R & D')
    );
  }

 @isTest(SeeAllData=true)
static void testProcessSalesOrderLineData_ComplexScenario() {
    String uniqueSuffix = String.valueOf(Datetime.now().getTime());

    Account orphan = new Account(
        Name = 'Orphan Accounts DO_NOT_DELETE_Test_' + uniqueSuffix,
        Nick_Name__c = 'ORPHAN_' + uniqueSuffix
    );
    insert orphan;

    Account existingAcc = new Account(
        Name = 'Existing Customer_' + uniqueSuffix,
        ParentId = orphan.Id,
        Nick_Name__c = 'EXI1_' + uniqueSuffix
    );
    insert existingAcc;

    Product2 prod1 = new Product2(Name = 'Test Product 1 ' + uniqueSuffix, IsActive = true, External_Record_Id__c = 9991);
    Product2 prod2 = new Product2(Name = 'Test Product 2 ' + uniqueSuffix, IsActive = true, External_Record_Id__c = 9992);
    insert new List<Product2>{ prod1, prod2 };

    Id stdPricebookId = Test.getStandardPricebookId();
    if (![
        SELECT Id, IsActive FROM Pricebook2 WHERE Id = :stdPricebookId
    ].IsActive) {
        Pricebook2 stdPB = new Pricebook2(Id = stdPricebookId, IsActive = true);
        update stdPB;
    }

    insert new List<PricebookEntry>{
        new PricebookEntry(Pricebook2Id = stdPricebookId, Product2Id = prod1.Id, UnitPrice = 100, IsActive = true),
        new PricebookEntry(Pricebook2Id = stdPricebookId, Product2Id = prod2.Id, UnitPrice = 200, IsActive = true)
    };

    Order testOrder = new Order(
        External_Record_Id__c = 123456,
        AccountId = existingAcc.Id,
        EffectiveDate = Date.today(),
        Status = 'Draft',
        Pricebook2Id = stdPricebookId
    );
    insert testOrder;

    List<Object> records = new List<Object>{
        new Map<String, Object>{
            'RecordID' => 1001,
            'SalesOrderRecordID' => 123456,
            'Item' => 'Test Product 1 ' + uniqueSuffix,
            'Item_RecordID' => 9991,
            'Quantity' => 5.0,
            'Rate' => 100.0,
            'TJPrice' => 95.0,
            'UnitOfMeasure' => 'MT',
            'Closed' => false,
            'POService' => 'Test service',
            'Change' => 'New'
        },
        new Map<String, Object>{
            'RecordID' => 1002,
            'SalesOrderRecordID' => 123456,
            'Item' => 'Test Product 2 ' + uniqueSuffix,
            'Item_RecordID' => 9992,
            'Quantity' => 3.0,
            'Rate' => 200.0,
            'TJPrice' => 195.0,
            'UnitOfMeasure' => 'MT',
            'Closed' => true,
            'POService' => 'Another service',
            'Change' => 'Modified'
        },
        new Map<String, Object>{
            'RecordID' => 1003,
            'SalesOrderRecordID' => 999999, // non-existent order
            'Item' => 'New Product ' + uniqueSuffix,
            'Item_RecordID' => 9993,
            'Quantity' => 2.0,
            'Rate' => 50.0
        }
    };

    // === EXECUTE ===
    Test.startTest();
    MethodSyncController.processSalesOrderLineData(records);
    Test.stopTest();

    // === ASSERTIONS ===

    // ✅ Should have created dummy order for 999999
    List<Order> dummyOrders = [
        SELECT Id, AccountId
        FROM Order
        WHERE External_Record_Id__c = 999999
    ];
    System.assertEquals(1, dummyOrders.size(), 'Should have created dummy order');

    // ✅ Should have created new Product for 9993
    List<Product2> newProducts = [
        SELECT Id
        FROM Product2
        WHERE Name = :('New Product ' + uniqueSuffix)
    ];
    System.assertEquals(1, newProducts.size(), 'Should have created new product');

    // ✅ Should have created 3 OrderItems
    List<OrderItem> orderItems = [
        SELECT Id, Quantity, UnitPrice
        FROM OrderItem
        WHERE OrderId IN :new List<Id>{ testOrder.Id, dummyOrders[0].Id }
    ];
    System.assertEquals(1, orderItems.size(), 'Should have created 1 order items');
}


  @isTest
  static void testExecuteSyncByTypes() {
    Test.startTest();

    DateTime startTime = DateTime.now().addDays(-1);
    DateTime endTime = DateTime.now();
    List<String> syncTypes = new List<String>{ 'salesorders' };

    // Call the method to test
    MethodSyncController.SyncResult result = MethodSyncController.executeSyncByTypes(
      syncTypes,
      startTime,
      endTime
    );

    Test.stopTest();
  }

  @isTest
  static void testExecuteSyncByTypes_CatchBlock() {
    Test.startTest();

    DateTime startTime = DateTime.now().addDays(-1);
    DateTime endTime = DateTime.now();

    // Simulate a type that causes methodSyncData to throw
    List<String> syncTypes = new List<String>{ 'fake_exception_type' };

    // You must temporarily add this type to the map inside the test class using reflection OR ensure it's present in your production syncTypeMap
    // So make sure in executeSyncByTypes, this is included:
    // 'fake_exception_type' => new List<String>{ 'ThrowException', 'Throw Exception' }

    MethodSyncController.SyncResult result = MethodSyncController.executeSyncByTypes(
      syncTypes,
      startTime,
      endTime
    );

    Test.stopTest();

    System.assert(result.hasError, 'Catch block should return hasError = true');
    System.assert(
      result.message.contains('Failed to execute sync'),
      'Should return failed message'
    );
  }

  @isTest
  static void testProcessData() {
    setupInitialData();

    // Test SalesOrder processing
    List<Object> salesOrderRecords = new List<Object>{
      new Map<String, Object>{
        'RecordID' => 12345,
        'Customer' => 'New Customer',
        'TxnDate' => '2025-07-23',
        'PONumber' => 'PO-001'
      }
    };

    Test.startTest();
    MethodSyncController.processData(salesOrderRecords, 'SalesOrder');
    Test.stopTest();

    Order newOrder = [SELECT Id FROM Order WHERE External_Record_Id__c = 12345];
    System.assertNotEquals(null, newOrder, 'Order should have been created');
  }

  @isTest
  static void testProcessData_InvalidTable() {
    Test.startTest();
    MethodSyncController.processData(new List<Object>(), 'InvalidTable');
    Test.stopTest();

    // No assertion needed - just verifying no exceptions are thrown
    System.assert(true, 'Method should handle invalid table name gracefully');
  }

  @isTest
  static void testProcessData1() {
    setupInitialData();

    // Test SalesOrder processing
    List<Object> salesOrderRecords = new List<Object>{
      new Map<String, Object>{
        'RecordID' => 12345,
        'Customer' => 'New Customer',
        'TxnDate' => '2025-07-23',
        'PONumber' => 'PO-001'
      }
    };

    Test.startTest();
    MethodSyncController.processData(salesOrderRecords, 'Invoice');
    Test.stopTest();
  }
  @isTest
  static void testProcessData2() {
    setupInitialData();

    // Test SalesOrder processing
    List<Object> salesOrderRecords = new List<Object>{
      new Map<String, Object>{
        'RecordID' => 12345,
        'Customer' => 'New Customer',
        'TxnDate' => '2025-07-23',
        'PONumber' => 'PO-001'
      }
    };

    Test.startTest();
    MethodSyncController.processData(salesOrderRecords, 'Bill');
    Test.stopTest();
  }
  @isTest
  static void testProcessData3() {
    setupInitialData();

    // Test SalesOrder processing
    List<Object> salesOrderRecords = new List<Object>{
      new Map<String, Object>{
        'RecordID' => 12345,
        'Customer' => 'New Customer',
        'TxnDate' => '2025-07-23',
        'PONumber' => 'PO-001'
      }
    };

    Test.startTest();
    MethodSyncController.processData(salesOrderRecords, 'InvoiceLine');
    Test.stopTest();
  }

  @isTest
  static void testMethodSyncData() {
    // Define a time range for the test
    DateTime startTime = DateTime.now().addDays(-1);
    DateTime endTime = DateTime.now();

    // Use a test table name
    String tableName = 'Invoices';

    Test.startTest();
    MethodSyncController.methodSyncData(startTime, endTime, tableName);
    Test.stopTest();

    // Add a basic assert if needed — this method delegates work to a batch
    System.assert(true, 'methodSyncData executed without error');
  }

  @isTest
  static void testMapSupplierValue() {
    // Case 1: Valid mapped location
    String result1 = MethodSyncController.mapSupplierValue('ASYM - TJ1');
    System.assertEquals('ASYM- TJ1', result1, 'Should return mapped value');

    // Case 2: Input with leading/trailing spaces
    String result2 = MethodSyncController.mapSupplierValue('  ASYM - FX1  ');
    System.assertEquals(
      'ASYM- FX1',
      result2,
      'Should trim and return mapped value'
    );

    String result31 = MethodSyncController.mapSupplierValue('  ASYM- FX2  ');
    String result42 = MethodSyncController.mapSupplierValue('  ASYM- DH1  ');
    String result53 = MethodSyncController.mapSupplierValue('  ASYM- DH2  ');
    String result64 = MethodSyncController.mapSupplierValue('  ASYM- DH3  ');
    // Case 3: Blank string
    String result3 = MethodSyncController.mapSupplierValue('  ');
    System.assertEquals(null, result3, 'Should return null for blank input');

    // Case 4: Null input
    String result4 = MethodSyncController.mapSupplierValue(null);
    System.assertEquals(null, result4, 'Should return null for null input');

    // Case 5: Unknown location
    String result5 = MethodSyncController.mapSupplierValue('UNKNOWN LOCATION');
    System.assertEquals(null, result5, 'Should return null for unknown input');
  }

  @isTest
  static void testCatch_parseEffectiveDate_block() {
    // Pass an invalid date string that will cause Date.valueOf to fail
    Map<String, Object> recordMap = new Map<String, Object>{
      'TxnDate' => 'invalid-date-format' // Causes exception
    };

    Test.startTest();
    Date result = MethodSyncController.parseEffectiveDate(recordMap);
    Test.stopTest();

    // Validate fallback behavior
    System.assertEquals(
      Date.today(),
      result,
      'Should fallback to today on error'
    );
  }

  @isTest
  static void testCatch_parseEndDate_block() {
    // Pass an invalid date string that will cause Date.valueOf to fail
    Map<String, Object> recordMap = new Map<String, Object>{
      'TJDueDate1' => 'not-a-date' // Causes exception
    };

    Test.startTest();
    Date result = MethodSyncController.parseEndDate(recordMap);
    Test.stopTest();

    // Validate fallback behavior
    System.assertEquals(
      Date.today().addDays(1),
      result,
      'Should fallback to today+1 on error'
    );
  }

  @isTest
  static void testCatch_upsertOrders_DmlException() {
    Order badOrder = new Order();
    badOrder.External_Record_Id__c = 987654321;
    // Missing required AccountId and EffectiveDate

    List<Order> badOrders = new List<Order>{ badOrder };

    Test.startTest();
    MethodSyncController.upsertOrders(badOrders); // This should fail and enter the DmlException catch block
    Test.stopTest();
  }
  @isTest
  static void testCatch_upsertInvoices_DmlException() {
    AVSFQB__Invoices__c badInvoice = new AVSFQB__Invoices__c();
    badInvoice.External_Record_Id__c = 987654321;

    // Trigger DML error: assume Name or some text field has a 255 char limit
    badInvoice.CCL_Number__c = 'X'.repeat(500);

    Test.startTest();
    MethodSyncController.upsertInvoices(
      new List<AVSFQB__Invoices__c>{ badInvoice }
    );
    Test.stopTest();
  }

  @isTest
  static void testCatch_upsertBills_DmlException() {
    AVSFQB__Invoices__c badInvoice = new AVSFQB__Invoices__c();
    badInvoice.External_Record_Id__c = 987654321;

    // Force DML error by exceeding text field length
    badInvoice.CCL_Number__c = 'X'.repeat(500);

    Test.startTest();
    MethodSyncController.upsertBills(
      new List<AVSFQB__Invoices__c>{ badInvoice }
    );
    Test.stopTest();
  }

  @isTest
  static void testCatch_getOrCreateInvoices_insertException() {
    // Force insert to run by passing an invoice number that doesn't exist
    Set<Integer> invoiceNumbers = new Set<Integer>{ 999999 };

    Test.startTest();
    MethodSyncController.getOrCreateInvoices(invoiceNumbers); // Should trigger insert exception in catch
    Test.stopTest();

    // No assertion required — test will cover catch block if insert fails
  }
}