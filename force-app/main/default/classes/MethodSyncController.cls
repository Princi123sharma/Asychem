/**
 * @description Controller for Method Sync Manager LWC component
 * @author AI Assistant
 * @date 2025
 */
public with sharing class MethodSyncController {
  private static final String API_BASE_URL = 'https://rest.method.me';
  private static final String API_KEY = 'NjdmNjBiNGMxODQwNmI5YTI3NTdlOWY5LjkyQzA2QUY0QzlEMzQxQ0E4QzRGOEE5REZBNDNEQjk2'; // TODO: Move to Custom Settings
  private static final Integer BATCH_SIZE = 200;
  private static final Integer MAX_CALLOUT_RETRIES = 3;

  // Default date range for data sync (yesterday's data)
  private static final DateTime DEFAULT_SYNC_START_TIME = DateTime.newInstance(
    Date.today(),
    Time.newInstance(0, 0, 0, 0)
  );
  private static final DateTime DEFAULT_SYNC_END_TIME = DateTime.newInstance(
    Date.today(),
    Time.newInstance(23, 59, 59, 0)
  );
  /**
   * @description Get available sync types for the LWC component
   * @return List of sync type options
   */
  @AuraEnabled(cacheable=true)
  public static List<SyncTypeOption> getSyncTypes() {
    List<SyncTypeOption> syncTypes = new List<SyncTypeOption>();

    syncTypes.add(
      new SyncTypeOption(
        'Sales Orders',
        'salesorders',
        'Sync sales order data from Method CRM'
      )
    );
    syncTypes.add(
      new SyncTypeOption(
        'Invoices',
        'invoices',
        'Sync invoice data from Method CRM'
      )
    );
    syncTypes.add(
      new SyncTypeOption('Bills', 'bills', 'Sync bill data from Method CRM')
    );
    syncTypes.add(
      new SyncTypeOption(
        'Invoice Products',
        'invoiceproducts',
        'Sync invoice product line items'
      )
    );
    syncTypes.add(
      new SyncTypeOption(
        'Sales Order Lines',
        'salesorderlines',
        'Sync sales order line items'
      )
    );
    //syncTypes.add(new SyncTypeOption('All Data Types', 'all', 'Sync all available data types'));

    return syncTypes;
  }

  /**
   * @description Execute sync for selected data types and date range
   * @param startDate Start date for sync
   * @param endDate End date for sync
   * @param syncTypes List of sync types to execute
   * @param methodName Specific method name to run (optional)
   * @return SyncResult with success/error information
   */
  @AuraEnabled
  public static SyncResult syncDataForDateRange(
    Date startDate,
    Date endDate,
    List<String> syncTypes,
    String methodName
  ) {
    System.debug('startDate ' + startDate);
    System.debug('endDate ' + endDate);
    try {
      // Validate inputs
      if (startDate == null || endDate == null) {
        return new SyncResult(
          true,
          'Start date and end date are required',
          null
        );
      }

      if (startDate > endDate) {
        return new SyncResult(
          true,
          'Start date cannot be after end date',
          null
        );
      }

      if (syncTypes == null || syncTypes.isEmpty()) {
        if (String.isBlank(methodName)) {
          return new SyncResult(
            true,
            'Please select at least one sync type or specify a method name',
            null
          );
        }
      }

      // Convert dates to DateTime
      DateTime startTime = DateTime.newInstance(
        startDate,
        Time.newInstance(0, 0, 0, 0)
      );
      DateTime endTime = DateTime.newInstance(
        endDate,
        Time.newInstance(23, 59, 59, 0)
      );
      return executeSyncByTypes(syncTypes, startTime, endTime);
    } catch (Exception e) {
      System.debug(
        'Error in syncDataForDateRange: ' +
          e.getMessage() +
          '\n' +
          e.getStackTraceString()
      );
      Logger.error(e.getMessage() + ' ' + e.getStackTraceString());
      Logger.saveLog();
      return new SyncResult(true, 'Sync failed: ' + e.getMessage(), null);
    }
  }

  /**
   * @description Execute sync by selected types
   * @param syncTypes List of sync types
   * @param startTime Start datetime
   * @param endTime End datetime
   * @return SyncResult
   */

  //Atul change to optimize the method executeSyncByTypes
  @TestVisible
  private static SyncResult executeSyncByTypes(
    List<String> syncTypes,
    DateTime startTime,
    DateTime endTime
  ) {
    try {
      String jobId = String.valueOf(DateTime.now().getTime());
      List<String> executedTypes = new List<String>();

      // Map of syncType => [tableName, friendlyDisplayName]
      Map<String, List<String>> syncTypeMap = new Map<String, List<String>>{
        'salesorders' => new List<String>{ 'SalesOrder', 'Sales Orders' },
        'invoices' => new List<String>{ 'Invoice', 'Invoices' },
        'bills' => new List<String>{ 'Bill', 'Bills' },
        'invoiceproducts' => new List<String>{
          'InvoiceLine',
          'Invoice Products'
        },
        'salesorderlines' => new List<String>{
          'SalesOrderLine',
          'Sales Order Lines'
        },
        'fake_exception_type' => new List<String>{
          'ThrowException',
          'Throw Exception'
        }
      };

      for (String syncType : syncTypes) {
        String lowerSyncType = syncType.toLowerCase();

        if (syncTypeMap.containsKey(lowerSyncType)) {
          List<String> syncInfo = syncTypeMap.get(lowerSyncType);
          String tableName = syncInfo[0];
          String friendlyName = syncInfo[1];

          methodSyncData(startTime, endTime, tableName); //Calling method to execute the batch process.
          executedTypes.add(friendlyName);
        }
      }

      if (executedTypes.isEmpty()) {
        return new SyncResult(true, 'No valid sync types were provided.', null);
      }

      String message =
        'Sync started successfully for: ' + String.join(executedTypes, ', ');
      return new SyncResult(false, message, jobId);
    } catch (Exception e) {
      System.debug('Error executing sync types: ' + e.getMessage());
      Logger.error(e.getMessage());
      Logger.saveLog();
      return new SyncResult(
        true,
        'Failed to execute sync: ' + e.getMessage(),
        null
      );
    }
  }

  /**
   * @description Public method to sync all data types with custom date range
   * @param startTime Start date and time for sync
   * @param endTime End date and time for sync
   *@param tableName consist of name of obejct for which we are syncing records.
   */

  public static void methodSyncData(
    DateTime startTime,
    DateTime endTime,
    String tableName
  ) {
    //Only for test class execution
    if (Test.isRunningTest() && tableName == 'ThrowException') {
      throw new AuraHandledException('Simulated test exception');
    }

    System.debug('Starting sync for :' + tableName);
    String endpoint = API_BASE_URL + '/api/v1/tables/' + tableName;

    // Properly format and encode filter
    String filter =
      'LastModifiedDate ge \'' +
      startTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss') +
      '\' and LastModifiedDate lt \'' +
      endTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss') +
      '\'';

    String encodedFilter = EncodingUtil.urlEncode(filter, 'UTF-8');

    String fullUrl = endpoint + '?&skip=0&top=100&filter=' + encodedFilter;

    System.debug('Initial invoice sync URL: ' + fullUrl); // <-- helpful debug
    Integer scopeSize = 1; // Each scope processes 1 skip offsets = 100 records max
    if (!Test.isRunningTest()) {
      System.enqueueJob(
        new FetchApiQueueable(tableName, startTime, endTime, 0, 1) // skip=0, chainCount=1
      );
    }
  }

  /**
   * @description Public method to process all the records fetched from api
   * @param records collection of records fetched from api
   *@param tableName consist of name of obejct for which we are syncing records.
   */
  public static void processData(List<Object> records, String tableName) {
    if (records == null || records.isEmpty()) {
      System.debug('No records to process');
      return;
    }
    if (tableName == 'SalesOrder') {
      processSalesOrderData(records);
    } else if (tableName == 'Invoice') {
      processInvoiceData(records);
    } else if (tableName == 'Bill') {
      processBillData(records);
    } else if (tableName == 'InvoiceLine') {
      processInvoiceProductData(records);
    } else if (tableName == 'SalesOrderLine') {
      processSalesOrderLineData(records);
    } else {
      system.debug('Table name undefiend');
    }
  }

  /**
   * @description Process Sales Order data with optimized bulk operations
   * @param records List of sales order records from API
   */
  public static void processSalesOrderData(List<Object> records) {
    System.debug('Processing ' + records.size() + ' Sales Order records');

    // Initialize collections
    List<Order> ordersToUpsert = new List<Order>();
    Set<String> customerNames = new Set<String>();
    Set<Integer> extRecordIds = new Set<Integer>();
    // Extract data from records
    try {
      for (Object record : records) {
        Map<String, Object> recordMap = (Map<String, Object>) record;
        if (recordMap == null)
          continue;

        Integer extRecordId = (Integer) recordMap.get('RecordID');
        String customerName = (String) recordMap.get('Customer');
        system.debug('@@@  customerName---' + customerName);
        if (extRecordId != null) {
          extRecordIds.add(extRecordId);
        }

        if (String.isNotBlank(customerName)) {
          customerNames.add(customerName);
        }
      }
    } catch (Exception e) {
      logger.error(e.getMessage());
      logger.savelog();
      System.debug(
        'Error extracting data from Sales Order records: ' + e.getMessage()
      );
      return;
    }

    // Query existing orders
    Map<Decimal, Order> existingOrdersMap = new Map<Decimal, Order>();
    try {
      for (Order existingOrder : [
        SELECT
          Id,
          AccountId,
          GMP_Requirements__c,
          PO_Type__c,
          Supplier__c,
          US_Tech__c,
          PCO__c,
          Lead_Time__c,
          External_Record_Id__c,
          Status,
          Client_PO_Number__c,
          EffectiveDate,
          EndDate,
          Ext_Internal_PO__c,
          Customer_Delivery_Terms__c
        FROM Order
        WHERE External_Record_Id__c IN :extRecordIds
        LIMIT 10000
      ]) {
        existingOrdersMap.put(
          existingOrder.External_Record_Id__c,
          existingOrder
        );
      }
    } catch (Exception e) {
      logger.error(e.getMessage());
      logger.savelog();
      System.debug('Error querying existing orders: ' + e.getMessage());
    }

    // Query existing accounts
    System.debug('customerNames ' + customerNames);
    Map<String, Id> customerNameToAccountId = getOrCreateAccounts(
      customerNames
    );
    System.debug('customerNameToAccountId ' + customerNameToAccountId);

    // 🔁 Fetch Orphan Account (added logic)
    Id orphanAccountId;
    try {
        orphanAccountId = [
            SELECT Id FROM Account WHERE Name = 'Orphan Accounts DO_NOT_DELETE' LIMIT 1
        ].Id;
        System.debug('✅ Found Orphan Account: ' + orphanAccountId);
    } catch (Exception e) {
        Logger.error('❌ Failed to find Orphan Account: ' + e.getMessage())
              .addTag('processSalesOrderData');
        logger.savelog();
        return;
    }
     // 🔁 Fetch Orphan Account (added logic end)
    // Process each record and create/update orders
    try {
      for (Object record : records) {
        Map<String, Object> recordMap = (Map<String, Object>) record;
        if (recordMap == null)
          continue;

        Order order = processIndividualSalesOrder(
          recordMap,
          existingOrdersMap,
          customerNameToAccountId,
          orphanAccountId
        );
        if (order != null) {
          ordersToUpsert.add(order);
        }

        // Batch processing to avoid memory issues
        /*if (ordersToUpsert.size() >= BATCH_SIZE) {
          upsertOrders(ordersToUpsert);
          ordersToUpsert.clear();
        }*/
      }

      system.debug('#####- ordersToUpsert-' + ordersToUpsert);

      // Process remaining orders
      if (!ordersToUpsert.isEmpty()) {
        upsertOrders(ordersToUpsert);
      }
    } catch (Exception e) {
      logger.error(e.getMessage());
      logger.savelog();
      System.debug(
        'Error processing Sales Order records: ' +
          e.getMessage() +
          '\n' +
          e.getStackTraceString()
      );
    }
  }
  /**
   * @description Get or create accounts for customer names
   * @param customerNames Set of customer names
   * @return Map of customer name to account ID
   */
  public static Map<String, Id> getOrCreateAccounts(Set<String> customerNames) {
    Map<String, Id> customerNameToAccountId = new Map<String, Id>();

    // Normalize input names
    Set<String> normalizedNames = new Set<String>();
    Map<String, String> normalizedToOriginalNameMap = new Map<String, String>();
    for (String name : customerNames) {
        if (String.isNotBlank(name)) {
            String trimmedName = name.trim();
            String normalized = trimmedName.toUpperCase();
            normalizedNames.add(normalized);
            normalizedToOriginalNameMap.put(normalized, trimmedName);
        }
    }

    if (normalizedNames.isEmpty()) {
        return customerNameToAccountId;
    }

    // Query existing accounts
    Set<String> originalNamesToMatch = new Set<String>(normalizedToOriginalNameMap.values());

    try {
        for (Account acc : [
            SELECT Id, Name
            FROM Account
            WHERE Name IN :originalNamesToMatch
        ]) {
            String accNormalized = acc.Name != null ? acc.Name.trim().toUpperCase() : '';
            if (normalizedNames.contains(accNormalized)) {
                customerNameToAccountId.put(accNormalized, acc.Id);
            }
        }
    } catch (Exception e) {
        Logger.error('Error querying existing accounts: ' + e.getMessage())
              .addTag('getOrCreateAccounts');
        logger.savelog();
    }

    return customerNameToAccountId;
}


  /**
   * @description Generate unique nickname for account
   * @param customerName Customer name
   * @param nickNameCounterMap Counter map for nicknames
   * @param existingNickNames Set of existing nicknames in the database
   * @return Generated unique nickname
   */
  private static String generateNickName(
    String customerName,
    Map<String, Integer> nickNameCounterMap,
    Set<String> existingNickNames
  ) {
    if (String.isBlank(customerName)) {
      customerName = 'UNKNOWN';
    }

    // Sanitize customer name: remove special characters and take first 5 characters for more uniqueness
    String sanitizedName = customerName.replaceAll('[^a-zA-Z0-9]', '')
      .toUpperCase();
    String baseNickName = sanitizedName.length() >= 5
      ? sanitizedName.substring(0, 5)
      : sanitizedName;
    String nickName = baseNickName;
    Integer counter = nickNameCounterMap.get(baseNickName) != null
      ? nickNameCounterMap.get(baseNickName)
      : 1;

    // Keep incrementing counter until a unique nickname is found
    while (existingNickNames.contains(nickName)) {
      nickName = baseNickName + counter;
      counter++;
    }

    nickNameCounterMap.put(baseNickName, counter);
    existingNickNames.add(nickName); // Prevent reuse in this batch
    return nickName;
  }

  /**
   * @description Process individual sales order record
   * @param recordMap Sales order record data
   * @param existingOrdersMap Map of existing orders
   * @param customerNameToAccountId Map of customer names to account IDs
   * @return Processed Order or null if invalid
   */
  public static Order processIndividualSalesOrder(
    Map<String, Object> recordMap,
    Map<Decimal, Order> existingOrdersMap,
    Map<String, Id> customerNameToAccountId,
    Id orphanAccountId 
  ) {
    // Keys are normalized (trimmed + uppercased)
    try {
      Integer extRecordId = (Integer) recordMap.get('RecordID');
      String customerName = (String) recordMap.get('Customer');

      if (extRecordId == null || String.isBlank(customerName)) {
        System.debug('⚠️ Skipping order with missing RecordID or Customer');
        return null;
      }

      // Normalize customer name to match key format in customerNameToAccountId map
      String normalizedCustomerName = customerName.trim().toUpperCase();
      Id accountId = customerNameToAccountId.get(normalizedCustomerName);
      Boolean isOrphan = false;

      if (accountId == null) {
            System.debug(
                '⚠️ No Account found for customer: ' +
                customerName +
                ' (normalized: ' +
                normalizedCustomerName +
                '). Using Orphan Account.'
            );
            accountId = orphanAccountId;
            isOrphan = true;
        }
      System.debug('🔍 Full recordMap: ' + JSON.serializePretty(recordMap));
      // Get or create Order
      Order order;
      if (existingOrdersMap.containsKey(Decimal.valueOf(extRecordId))) {
        order = existingOrdersMap.get(Decimal.valueOf(extRecordId));
        System.debug('🔄 Updating existing order for RecordID: ' + extRecordId);
      } else {
        order = new Order(External_Record_Id__c = Decimal.valueOf(extRecordId));
        System.debug('🆕 Creating new order for RecordID: ' + extRecordId);
      }

      // Set mandatory fields
      order.AccountId = accountId;
      order.Name = customerName;
      order.Status = 'Draft';

      // ✅ Store original customer name if Orphan used
        if (isOrphan) {
            order.Original_Customer_Name__c = customerName;
        }

      // Handle dates safely
      order.EffectiveDate = parseEffectiveDate(recordMap);
      order.EndDate = parseEndDate(recordMap);

      // Optional fields mapping
      order.Client_PO_Number__c = (String) recordMap.get('PONumber'); // text
      order.PO_Type__c = (String) recordMap.get('POType'); // picklist 
      order.Lead_Time__c = (String) recordMap.get('TotalLeadTime'); // text
      order.Ext_Internal_PO__c = (String) recordMap.get('RefNumber'); // text
      order.Customer_Delivery_Terms__c = (String) recordMap.get(
        'CustomerDeliveryTerms'
      ); // text
      order.PCO__c = (String) recordMap.get('TJProjContact'); // text
      order.US_Tech__c = (String) recordMap.get('USATechContact'); // text
      order.GMP_Requirements__c = (String) recordMap.get('GMPStatus'); // picklist (not provided)

      // Supplier picklist value mapping
      String supplierValue = mapSupplierValue(
        (String) recordMap.get('Location')
      );
      if (supplierValue != null) {
        order.Supplier__c = supplierValue;
      }

    String billingStreet = String.join(new List<String>{
    (String)recordMap.get('BillAddressAddr1'),
    (String)recordMap.get('BillAddressAddr2'),
    (String)recordMap.get('BillAddressAddr3'),
    (String)recordMap.get('BillAddressAddr4'),
    (String)recordMap.get('BillAddressAddr5')
    }, '\n');

      order.BillingStreet     = String.isBlank(billingStreet) ? null : billingStreet;
      order.BillingCity       = (String) recordMap.get('BillAddressCity');
      order.BillingState      = (String) recordMap.get('BillAddressState');
      order.BillingPostalCode = (String) recordMap.get('BillAddressPostalCode');
      order.BillingCountry    = (String) recordMap.get('BillAddressCountry');

      // --- Map Shipping Address ---
      String shippingStreet = String.join(new List<String>{
          (String)recordMap.get('ShipAddressAddr1'),
          (String)recordMap.get('ShipAddressAddr2'),
          (String)recordMap.get('ShipAddressAddr3'),
          (String)recordMap.get('ShipAddressAddr4'),
          (String)recordMap.get('ShipAddressAddr5')
      }, '\n');

      order.ShippingStreet     = String.isBlank(shippingStreet) ? null : shippingStreet;
      order.ShippingCity       = (String) recordMap.get('ShipAddressCity');
      order.ShippingState      = (String) recordMap.get('ShipAddressState');
      order.ShippingPostalCode = (String) recordMap.get('ShipAddressPostalCode');
      order.ShippingCountry    = (String) recordMap.get('ShipAddressCountry');
      system.debug('###-- Order- '+ order);
      return order;
    } catch (Exception e) {
      logger.error(e.getMessage());
      logger.savelog();
      System.debug(
        '❌ Error processing individual sales order: ' +
          e.getMessage() +
          '\n' +
          e.getStackTraceString()
      );
      return null;
    }
  }

  /**
   * @description Parse end date from record map
   * @param recordMap Record data
   * @return Parsed end date or default
   */
  @TestVisible
  private static Date parseEndDate(Map<String, Object> recordMap) {
    try {
      String tjDueDate = (String) recordMap.get('TJDueDate1');
      if (String.isNotBlank(tjDueDate)) {
        Date potentialEndDate = Date.valueOf(tjDueDate);
        return potentialEndDate >= Date.today()
          ? potentialEndDate
          : Date.today();
      }
    } catch (Exception e) {
      logger.error(e.getMessage());
      logger.savelog();
      System.debug('Error parsing TJDueDate1: ' + e.getMessage());
    }
    return Date.today().addDays(1);
  }

  /**
   * @description Parse effective date from record map
   * @param recordMap Record data
   * @return Parsed effective date or today
   */
  @TestVisible
  private static Date parseEffectiveDate(Map<String, Object> recordMap) {
    try {
      String txnDate = (String) recordMap.get('TxnDate');
      if (String.isNotBlank(txnDate)) {
        return Date.valueOf(txnDate);
      }
    } catch (Exception e) {
      logger.error(e.getMessage());
      logger.savelog();
      System.debug('Error parsing TxnDate: ' + e.getMessage());
    }
    return Date.today();
  }

  /**
   * @description Map supplier location to valid picklist value
   * @param location Raw location value
   * @return Mapped supplier value or null
   */
  @TestVisible
  private static String mapSupplierValue(String location) {
    if (String.isBlank(location)) {
      return null;
    }

    Map<String, String> supplierMapping = new Map<String, String>{
      'ASYM - TJ1' => 'ASYM- TJ1',
      'ASYM - TJ2' => 'ASYM- TJ2',
      'ASYM - TJ3' => 'ASYM- TJ3',
      'ASYM - FX1' => 'ASYM- FX1',
      'ASYM - FX2' => 'ASYM- FX2',
      'ASYM - DH1' => 'ASYM- DH1',
      'ASYM - DH2' => 'ASYM- DH2',
      'ASYM - DH3' => 'ASYM- DH3',
      'ASYM - BOSTON' => 'ASYM- BOSTON'
    };

    String trimmedLocation = location.trim();
    if (supplierMapping.containsKey(trimmedLocation)) {
      return supplierMapping.get(trimmedLocation);
    }

    System.debug('Unknown Supplier value: ' + location);
    return null;
  }

  /**
   * @description Upsert orders with error handling
   * @param orders List of orders to upsert
   */
  public static void upsertOrders(List<Order> orders) {
    if (orders == null || orders.isEmpty()) {
      return;
    }

    try {
      upsert orders External_Record_Id__c;
      System.debug('Successfully upserted ' + orders.size() + ' orders');
    } catch (DmlException e) {
      logger.error(e.getMessage());
      System.debug('DML Error upserting orders: ' + e.getMessage());
      for (Integer i = 0; i < e.getNumDml(); i++) {
        System.debug('DML Error on record ' + i + ': ' + e.getDmlMessage(i));
      }
      logger.savelog();
    }
  }

  /**
   * @description Process Invoice data with optimized bulk operations
   * @param records List of invoice records from API
   */
  public static void processInvoiceData(List<Object> records) {
    if (records == null || records.isEmpty()) {
      System.debug('No Invoice records to process');
      return;
    }

    System.debug('Processing ' + records.size() + ' Invoice records');

    Set<Integer> extRecordIds = new Set<Integer>();
    Map<Integer, AVSFQB__Invoices__c> recordIdToInvoiceMap = new Map<Integer, AVSFQB__Invoices__c>();

    // Extract external record IDs
    for (Object record : records) {
      Map<String, Object> recordMap = (Map<String, Object>) record;
      Integer extRecordId = (Integer) recordMap.get('RecordID');
      if (extRecordId != null) {
        extRecordIds.add(extRecordId);
      }
    }

    // Query existing invoices
    Map<Decimal, AVSFQB__Invoices__c> existingInvoicesMap = new Map<Decimal, AVSFQB__Invoices__c>();
    try {
      for (AVSFQB__Invoices__c existingInvoice : [
        SELECT
          Id,
          External_Record_Id__c,
          AVSFQB__Invoice_Number__c,
          Client_Name__c,
          AVSFQB__TxnDate__c,
          P_O__c,
          Issued_by__c,
          S_O__c,
          Type__c
        FROM AVSFQB__Invoices__c
        WHERE External_Record_Id__c IN :extRecordIds
        LIMIT 10000
      ]) {
        existingInvoicesMap.put(
          existingInvoice.External_Record_Id__c,
          existingInvoice
        );
      }
    } catch (Exception e) {
      logger.error(e.getMessage());
      logger.savelog();
      System.debug('Error querying existing invoices: ' + e.getMessage());
    }

    // Process records
    try {
      for (Object record : records) {
        Map<String, Object> recordMap = (Map<String, Object>) record;
        Integer extRecordId = (Integer) recordMap.get('RecordID');

        if (
          extRecordId == null || recordIdToInvoiceMap.containsKey(extRecordId)
        ) {
          continue; // Skip duplicate or null ID
        }

        AVSFQB__Invoices__c invoice = processIndividualInvoice(
          recordMap,
          existingInvoicesMap
        );
        if (invoice != null) {
          recordIdToInvoiceMap.put(extRecordId, invoice);
        }
      }

      // Upsert invoices
      if (!recordIdToInvoiceMap.isEmpty()) {
        upsertInvoices(
          new List<AVSFQB__Invoices__c>(recordIdToInvoiceMap.values())
        );
      }
    } catch (Exception ex) {
      logger.error(ex.getMessage());
      logger.savelog();
      System.debug(
        'Error processing Invoice records: ' +
          ex.getMessage() +
          '\n' +
          ex.getStackTraceString()
      );
    }
  }

  /**
   * @description Process individual invoice record
   * @param recordMap Invoice record data
   * @param existingInvoicesMap Map of existing invoices
   * @return Processed Invoice or null if invalid
   */
  public static AVSFQB__Invoices__c processIndividualInvoice(
    Map<String, Object> recordMap,
    Map<Decimal, AVSFQB__Invoices__c> existingInvoicesMap
  ) {
    try {
      Integer extRecordId = (Integer) recordMap.get('RecordID');
      if (extRecordId == null) {
        return null;
      }

      AVSFQB__Invoices__c invoice = existingInvoicesMap.containsKey(extRecordId)
        ? existingInvoicesMap.get(extRecordId)
        : new AVSFQB__Invoices__c(External_Record_Id__c = extRecordId);

      // Map fields with validation
      invoice.AVSFQB__Invoice_Number__c = (String) recordMap.get('RefNumber');
      invoice.Client_Name__c = (String) recordMap.get('Customer');
      invoice.P_O__c = (String) recordMap.get('PONumber');
      invoice.Issued_by__c = (String) recordMap.get('AssignedTo');
      invoice.S_O__c = (String) recordMap.get('SalesOrderNo');
      invoice.Type__c = 'Invoice';
      String billingStreet = String.join(new List<String>{
          (String)recordMap.get('BillAddressAddr1'),
          (String)recordMap.get('BillAddressAddr2'),
          (String)recordMap.get('BillAddressAddr3'),
          (String)recordMap.get('BillAddressAddr4'),
          (String)recordMap.get('BillAddressAddr5')
          }, '\n');

        // Retrieve values from the map first
    //     String billingCountry = (String) recordMap.get('BillAddressCountry');
    //     String billingState = (String) recordMap.get('BillAddressState');

    //     // Always assign the values that don't have dependencies
    //     invoice.Billing_Address__Street__s     = String.isBlank(billingStreet) ? null : billingStreet;
    //     invoice.Billing_Address__City__s       = (String) recordMap.get('BillAddressCity');
    //     invoice.Billing_Address__PostalCode__s = (String) recordMap.get('BillAddressPostalCode');

    //     // Assign country
    //     invoice.Billing_Address__CountryCode__s = billingCountry;

    //     // --- CRITICAL CHANGE ---
    //     // Only assign the state if the country is also present.
    //     if (String.isNotBlank(billingCountry) && String.isNotBlank(billingState)) {
    //         invoice.Billing_Address__StateCode__s = billingState;
    //     } else {
    //         // If there's no country, we cannot set a state, so ensure it's null.
    //         invoice.Billing_Address__StateCode__s = null; 
    //     }
    //   // --- Map Shipping Address ---
    //   String shippingStreet = String.join(new List<String>{
    //       (String)recordMap.get('ShipAddressAddr1'),
    //       (String)recordMap.get('ShipAddressAddr2'),
    //       (String)recordMap.get('ShipAddressAddr3'),
    //       (String)recordMap.get('ShipAddressAddr4'),
    //       (String)recordMap.get('ShipAddressAddr5')
    //   }, '\n'); 

    //   // Retrieve shipping address values from the map first
    //     String shippingCountry = (String) recordMap.get('ShipAddressCountry');
    //     String shippingState = (String) recordMap.get('ShipAddressState');

    //     // Always assign the values that don't have dependencies
    //     invoice.Shipping_Address__Street__s     = String.isBlank(shippingStreet) ? null : shippingStreet;
    //     invoice.Shipping_Address__City__s       = (String) recordMap.get('ShipAddressCity');
    //     invoice.Shipping_Address__PostalCode__s = (String) recordMap.get('ShipAddressPostalCode');

    //     // Assign country
    //     invoice.Shipping_Address__CountryCode__s = shippingCountry;

    //     // --- CRITICAL CHANGE ---
    //     // Only assign the state if the country is also present.
    //     if (String.isNotBlank(shippingCountry) && String.isNotBlank(shippingState)) {
    //         invoice.Shipping_Address__StateCode__s = shippingState;
    //     } else {
    //         // If there's no country, we cannot set a state, so ensure it's null.
    //         invoice.Shipping_Address__StateCode__s = null; 
    //     }

      // Handle date parsing
      try {
        String txnDate = (String) recordMap.get('TxnDate');
        if (String.isNotBlank(txnDate)) {
          invoice.AVSFQB__TxnDate__c = Date.valueOf(txnDate);
        }
      } catch (Exception e) {
        logger.error(e.getMessage());
        logger.savelog();
        System.debug(
          'Error parsing TxnDate for invoice ' +
            extRecordId +
            ': ' +
            e.getMessage()
        );
        invoice.AVSFQB__TxnDate__c = Date.today();
      }

       try {
        String dueDate = (String) recordMap.get('DueDate');
        if (String.isNotBlank(dueDate)) {
          dueDate = dueDate.replace('T', ' ');
          invoice.Due_Date__c = Datetime.valueOf(dueDate);
        }
      } catch (Exception e) {
        logger.error(e.getMessage());
        logger.savelog();
        System.debug(
          'Error parsing dueDate for invoice ' +
            extRecordId +
            ': ' +
            e.getMessage()
        );
        //invoice.Due_Date__c = Date.today();
      }

      return invoice;
    } catch (Exception e) {
      logger.error(e.getMessage());
      logger.savelog();
      System.debug('Error processing individual invoice: ' + e.getMessage());
      return null;
    }
  }

  /**
   * @description Upsert invoices with error handling
   * @param invoices List of invoices to upsert
   */
  public static void upsertInvoices(List<AVSFQB__Invoices__c> invoices) {
    if (invoices == null || invoices.isEmpty()) {
      return;
    }

    try {
      upsert invoices External_Record_Id__c;
      System.debug('Successfully upserted ' + invoices.size() + ' invoices');
    } catch (DmlException e) {
      logger.error(e.getMessage());
      logger.savelog();
      System.debug('DML Error upserting invoices: ' + e.getMessage());
      for (Integer i = 0; i < e.getNumDml(); i++) {
        System.debug('DML Error on record ' + i + ': ' + e.getDmlMessage(i));
      }
    }
  }

  /**
   * @description Process Bill data with optimized bulk operations
   * @param records List of bill records from API
   */
  public static void processBillData(List<Object> records) {
    if (records == null || records.isEmpty()) {
      System.debug('No Bill records to process');
      return;
    }
    System.debug('@@@ processBillData called ');
    System.debug('Processing ' + records.size() + ' Bill records');

    Set<Integer> billNumbers = new Set<Integer>();
    List<AVSFQB__Invoices__c> billsToUpsert = new List<AVSFQB__Invoices__c>();

    // Extract bill numbers
    for (Object record : records) {
      Map<String, Object> recordMap = (Map<String, Object>) record;
      Integer billNumber = (Integer) recordMap.get('RecordID');
      if (billNumber != null) {
        billNumbers.add(billNumber);
      }
    }

    // Query existing bills
    Map<Decimal, AVSFQB__Invoices__c> existingBillsMap = new Map<Decimal, AVSFQB__Invoices__c>();
    try {
      for (AVSFQB__Invoices__c existingBill : [
        SELECT
          Id,
          External_Record_Id__c,
          AVSFQB__Invoice_Number__c,
          Client_Name__c,
          AVSFQB__TxnDate__c,
          AVSFQB__Total_Invoice_Amount__c,
          Type__c
        FROM AVSFQB__Invoices__c
        WHERE External_Record_Id__c IN :billNumbers
        LIMIT 10000
      ]) {
        existingBillsMap.put(existingBill.External_Record_Id__c, existingBill);
      }
    } catch (Exception e) {
      logger.error(e.getMessage());
      logger.savelog();
      System.debug('Error querying existing bills: ' + e.getMessage());
    }

    // Process records
    try {
      for (Object record : records) {
        Map<String, Object> recordMap = (Map<String, Object>) record;
        AVSFQB__Invoices__c bill = processIndividualBill(
          recordMap,
          existingBillsMap
        );
        if (bill != null) {
          billsToUpsert.add(bill);
        }

        // Batch processing
        if (billsToUpsert.size() >= BATCH_SIZE) {
          upsertBills(billsToUpsert);
          billsToUpsert.clear();
        }
      }

      // Process remaining bills
      if (!billsToUpsert.isEmpty()) {
        upsertBills(billsToUpsert);
      }
    } catch (Exception ex) {
      logger.error(ex.getMessage());
      logger.savelog();
      System.debug(
        'Error processing Bill records: ' +
          ex.getMessage() +
          '\n' +
          ex.getStackTraceString()
      );
    }
  }

  /**
   * @description Process individual bill record
   * @param recordMap Bill record data
   * @param existingBillsMap Map of existing bills
   * @return Processed Bill or null if invalid
   */
  private static AVSFQB__Invoices__c processIndividualBill(
    Map<String, Object> recordMap,
    Map<Decimal, AVSFQB__Invoices__c> existingBillsMap
  ) {
    try {
      Integer billNumber = (Integer) recordMap.get('RecordID');
      if (billNumber == null) {
        return null;
      }

      AVSFQB__Invoices__c bill = existingBillsMap.containsKey(billNumber)
        ? existingBillsMap.get(billNumber)
        : new AVSFQB__Invoices__c(External_Record_Id__c = billNumber);

      // Map fields with validation
      bill.Client_Name__c = (String) recordMap.get('Vendor');
      bill.AVSFQB__Invoice_Number__c = (String) recordMap.get('RefNumber');
      bill.Type__c = 'Bill';

      // Handle amount
      Object openAmount = recordMap.get('OpenAmount');
      if (openAmount != null) {
        bill.AVSFQB__Total_Invoice_Amount__c = (Decimal) openAmount;
      }

      // Handle date parsing
      try {
        String txnDate = (String) recordMap.get('TxnDate');
        if (String.isNotBlank(txnDate)) {
          bill.AVSFQB__TxnDate__c = Date.valueOf(txnDate);
        }
      } catch (Exception e) {
        logger.error(e.getMessage());
        logger.savelog();
        System.debug(
          'Error parsing TxnDate for bill ' + billNumber + ': ' + e.getMessage()
        );
        bill.AVSFQB__TxnDate__c = Date.today();
      }

      return bill;
    } catch (Exception e) {
      logger.error(e.getMessage());
      logger.savelog();
      System.debug('Error processing individual bill: ' + e.getMessage());
      return null;
    }
  }

  /**
   * @description Upsert bills with error handling
   * @param bills List of bills to upsert
   */
  @TestVisible
  private static void upsertBills(List<AVSFQB__Invoices__c> bills) {
    if (bills == null || bills.isEmpty()) {
      return;
    }

    try {
      upsert bills External_Record_Id__c;
      System.debug('Successfully upserted ' + bills.size() + ' bills');
    } catch (DmlException e) {
      logger.error(e.getMessage());
      logger.savelog();
      System.debug('DML Error upserting bills: ' + e.getMessage());
      for (Integer i = 0; i < e.getNumDml(); i++) {
        System.debug('DML Error on record ' + i + ': ' + e.getDmlMessage(i));
      }
    }
  }

  /**
   * @description Process Invoice Product data with optimized bulk operations
   * @param records List of invoice product records from API
   */
  public static void processInvoiceProductData(List<Object> records) {
    if (records == null || records.isEmpty()) {
      System.debug('No Invoice Product records to process');
      return;
    }

    System.debug('Processing ' + records.size() + ' Invoice Product records');

    Set<Integer> extRecordIds = new Set<Integer>();
    Set<Integer> invoiceNumbers = new Set<Integer>();

    // Extract IDs from records
    for (Object record : records) {
      Map<String, Object> recordMap = (Map<String, Object>) record;
      Integer extRecordId = (Integer) recordMap.get('RecordID');
      Integer invoiceNumber = (Integer) recordMap.get('InvoiceRecordID');

      if (extRecordId != null) {
        extRecordIds.add(extRecordId);
      }
      if (invoiceNumber != null) {
        invoiceNumbers.add(invoiceNumber);
      }
    }

    // Query existing invoice products
    Map<Decimal, Invoice_Products__c> existingProductsMap = new Map<Decimal, Invoice_Products__c>();
    try {
      for (Invoice_Products__c existingProduct : [
        SELECT
          Id,
          Name,
          Invoice__c,
          CCL_Number__c,
          Compound__c,
          Quantity__c,
          Unit_Price__c,
          Total_Price__c,
          QB_Item_Class__c,
          External_Record_Id__c,
          PO_Service_Activity__c
        FROM Invoice_Products__c
        WHERE External_Record_Id__c IN :extRecordIds
        LIMIT 10000
      ]) {
        existingProductsMap.put(
          existingProduct.External_Record_Id__c,
          existingProduct
        );
      }
    } catch (Exception e) {
      logger.error(e.getMessage());
      logger.savelog();
      System.debug(
        'Error querying existing invoice products: ' + e.getMessage()
      );
    }

    // Get or create invoice mappings
    Map<Decimal, Id> invoiceNumberToId = getOrCreateInvoices(invoiceNumbers);

    // Process records
    List<Invoice_Products__c> productsToUpsert = new List<Invoice_Products__c>();
    try {
      for (Object record : records) {
        Map<String, Object> recordMap = (Map<String, Object>) record;
        Invoice_Products__c product = processIndividualInvoiceProduct(
          recordMap,
          existingProductsMap,
          invoiceNumberToId
        );
        if (product != null) {
          productsToUpsert.add(product);
        }

        // Batch processing
        if (productsToUpsert.size() >= BATCH_SIZE) {
          upsertInvoiceProducts(productsToUpsert);
          productsToUpsert.clear();
        }
      }

      // Process remaining products
      if (!productsToUpsert.isEmpty()) {
        upsertInvoiceProducts(productsToUpsert);
      }
    } catch (Exception ex) {
      logger.error(ex.getMessage());
      logger.savelog();
      System.debug(
        'Error processing Invoice Product records: ' +
          ex.getMessage() +
          '\n' +
          ex.getStackTraceString()
      );
    }
  }

  /**
   * @description Get or create invoices for invoice numbers
   * @param invoiceNumbers Set of invoice numbers
   * @return Map of invoice number to invoice ID
   */
  @TestVisible
  private static Map<Decimal, Id> getOrCreateInvoices(
    Set<Integer> invoiceNumbers
  ) {
    Map<Decimal, Id> invoiceNumberToId = new Map<Decimal, Id>();
    List<AVSFQB__Invoices__c> invoicesToInsert = new List<AVSFQB__Invoices__c>();

    // Query existing invoices
    try {
      for (AVSFQB__Invoices__c inv : [
        SELECT Id, External_Record_Id__c
        FROM AVSFQB__Invoices__c
        WHERE External_Record_Id__c IN :invoiceNumbers
        LIMIT 10000
      ]) {
        invoiceNumberToId.put(inv.External_Record_Id__c, inv.Id);
      }
    } catch (Exception e) {
      logger.error(e.getMessage());
      logger.savelog();
      System.debug('Error querying existing invoices: ' + e.getMessage());
    }

    // Create missing invoices
    for (Integer invoiceNumber : invoiceNumbers) {
      if (!invoiceNumberToId.containsKey(invoiceNumber)) {
        invoicesToInsert.add(
          new AVSFQB__Invoices__c(
            External_Record_Id__c = invoiceNumber,
            Type__c = 'Invoice'
          )
        );
      }
    }

    // Insert new invoices
    if (!invoicesToInsert.isEmpty()) {
      try {
        insert invoicesToInsert;
        for (AVSFQB__Invoices__c inv : invoicesToInsert) {
          invoiceNumberToId.put(inv.External_Record_Id__c, inv.Id);
        }
        System.debug(
          'Created ' + invoicesToInsert.size() + ' placeholder invoices'
        );
      } catch (Exception ex) {
        logger.error(ex.getMessage());
        logger.savelog();
        System.debug(
          'Error inserting placeholder invoices: ' +
            ex.getMessage() +
            '\n' +
            ex.getStackTraceString()
        );
      }
    }

    return invoiceNumberToId;
  }

  /**
   * @description Process individual invoice product record
   * @param recordMap Invoice product record data
   * @param existingProductsMap Map of existing products
   * @param invoiceNumberToId Map of invoice numbers to IDs
   * @return Processed Invoice Product or null if invalid
   */
  private static Invoice_Products__c processIndividualInvoiceProduct(
    Map<String, Object> recordMap,
    Map<Decimal, Invoice_Products__c> existingProductsMap,
    Map<Decimal, Id> invoiceNumberToId
  ) {
    try {
      Integer extRecordId = (Integer) recordMap.get('RecordID');
      Integer invoiceNumber = (Integer) recordMap.get('InvoiceRecordID');

      if (extRecordId == null || invoiceNumber == null) {
        System.debug(
          'Skipping invoice product with missing RecordID or InvoiceRecordID'
        );
        return null;
      }

      Invoice_Products__c product;
      if (existingProductsMap.containsKey(extRecordId)) {
        product = existingProductsMap.get(extRecordId);
      } else {
        product = new Invoice_Products__c(External_Record_Id__c = extRecordId);
        if (invoiceNumberToId.containsKey(invoiceNumber)) {
          product.Invoice__c = invoiceNumberToId.get(invoiceNumber);
        } else {
          System.debug('No Invoice found for InvoiceNumber: ' + invoiceNumber);
          return null;
        }
      }

      // Map fields with validation
      product.Name = (String) recordMap.get('Item');
      product.QB_Item_Class__c = (String) recordMap.get('Class');
      product.PO_Service_Activity__c = (String) recordMap.get('POService');
      product.Compound__c = (String) recordMap.get('ChemicalName');
      product.CCL_Number__c = (String) recordMap.get('CCLNumber');

      // Handle numeric fields
      Object amount = recordMap.get('Amount');
      if (amount != null) {
        product.Total_Price__c = (Decimal) amount;
      }

      Object rate = recordMap.get('Rate');
      if (rate != null) {
        product.Unit_Price__c = (Decimal) rate;
      }

      Object quantity = recordMap.get('Quantity');
      if (quantity != null) {
        product.Quantity__c = (Decimal) quantity;
      }

      return product;
    } catch (Exception e) {
      logger.error(e.getMessage());
      logger.savelog();
      System.debug(
        'Error processing individual invoice product: ' + e.getMessage()
      );
      return null;
    }
  }

  /**
   * @description Upsert invoice products with error handling
   * @param products List of invoice products to upsert
   */
  private static void upsertInvoiceProducts(
    List<Invoice_Products__c> products
  ) {
    if (products == null || products.isEmpty()) {
      return;
    }

    try {
      upsert products External_Record_Id__c;
      System.debug(
        'Successfully upserted ' + products.size() + ' invoice products'
      );
    } catch (DmlException e) {
      System.debug('DML Error upserting invoice products: ' + e.getMessage());
      for (Integer i = 0; i < e.getNumDml(); i++) {
        System.debug('DML Error on record ' + i + ': ' + e.getDmlMessage(i));
      }
      logger.error(e.getMessage());
      logger.savelog();
    } catch (Exception e) {
      logger.error(e.getMessage());
      logger.savelog();
      System.debug(
        'Unexpected error upserting invoice products: ' +
          e.getMessage() +
          '\n' +
          e.getStackTraceString()
      );
    }
  }

 public static void processSalesOrderLineData(List<Object> records) {
    if (records == null || records.isEmpty()) {
        System.debug('No Sales Order Line records to process');
        return;
    }

    System.debug('Processing ' + records.size() + ' Sales Order Line records');

    List<OrderItem> linesToUpsert = new List<OrderItem>();
    Set<String> chemicalNames = new Set<String>();
    Set<Decimal> itemRecordIds = new Set<Decimal>();
    Set<String> itemNames = new Set<String>();
    Set<Decimal> orderRecordIds = new Set<Decimal>();
    Set<Integer> extRecordIds = new Set<Integer>();

    // Extract data from records
    try {
        for (Object record : records) {
            Map<String, Object> recordMap = (Map<String, Object>) record;
            if (recordMap == null) continue;

            String chemicalName = (String) recordMap.get('ChemicalName');
            Integer orderRecordId = (Integer) recordMap.get('SalesOrderRecordID');
            Integer itemRecordId = (Integer) recordMap.get('Item_RecordID');
            String itemName = (String) recordMap.get('Item');
            Integer extRecordId = (Integer) recordMap.get('RecordID');

            if (extRecordId != null) extRecordIds.add(extRecordId);
            if (String.isNotBlank(chemicalName)) chemicalNames.add(chemicalName);
            if (itemRecordId != null) itemRecordIds.add((Decimal)itemRecordId);
            if (orderRecordId != null) orderRecordIds.add((Decimal)orderRecordId);
            if (String.isNotBlank(itemName)) itemNames.add(normalizeProductName(itemName));
        }
    } catch (Exception e) {
        logger.error(e.getMessage());
        logger.savelog();
        System.debug('Error extracting data: ' + e.getMessage());
        return;
    }
     
    // Query matching Compounds once, based on chemicalNames we collected
    Map<String, Id> compoundNameToId = new Map<String, Id>();
    if (!chemicalNames.isEmpty()) {
        for (Compound__c cmp : [
            SELECT Id, Name
            FROM Compound__c
            WHERE Name IN :chemicalNames
        ]) {
            compoundNameToId.put(cmp.Name, cmp.Id);
        }
    }

    // Query existing Order Items
    Map<Decimal, OrderItem> existingOrderItemMap = new Map<Decimal, OrderItem>();
    for (OrderItem existingOrderItem : [
        SELECT Id, External_Record_Id__c, Product2Id, OrderId, PricebookEntryId
        FROM OrderItem
        WHERE External_Record_Id__c IN :extRecordIds
    ]) {
        existingOrderItemMap.put(existingOrderItem.External_Record_Id__c, existingOrderItem);
    }

    // Query existing Products
    Map<String, Id> itemNameToProductId = new Map<String, Id>();
    Map<Decimal, Id> itemRecordIdToProductId = new Map<Decimal, Id>();
    for (Product2 product : [
        SELECT Id, Name, External_Record_Id__c
        FROM Product2
        WHERE Name IN :itemNames OR External_Record_Id__c IN :itemRecordIds
    ]) {
        itemNameToProductId.put(product.Name, product.Id);
        if (product.External_Record_Id__c != null) {
            itemRecordIdToProductId.put(product.External_Record_Id__c, product.Id);
        }
    }

    // Get standard pricebook
    Id standardPricebookId = [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1].Id;

    // Process Orders
    Map<Decimal, Order> orderRecordIdToOrder = new Map<Decimal, Order>();
    List<Order> ordersNeedingPricebook = new List<Order>();
    
    for (Order order : [
        SELECT Id, External_Record_Id__c, Pricebook2Id
        FROM Order
        WHERE External_Record_Id__c IN :orderRecordIds
    ]) {
        if (order.Pricebook2Id == null) {
            ordersNeedingPricebook.add(new Order(Id = order.Id, Pricebook2Id = standardPricebookId));
        }
        orderRecordIdToOrder.put(order.External_Record_Id__c, order);
    }

    // Update Orders needing pricebook
    if (!ordersNeedingPricebook.isEmpty()) {
        update ordersNeedingPricebook;
    }

    // Create dummy Account if needed
    Account dummyAccount;
    try {
        dummyAccount = [SELECT Id FROM Account WHERE Name = 'create dummy acc' LIMIT 1];
    } catch (Exception e) {
        dummyAccount = new Account(Name = 'create dummy acc', Nick_Name__c = 'create dummy');
        insert dummyAccount;
    }

    // Create missing Orders
    List<Order> newOrdersToInsert = new List<Order>();
    for (Decimal orderNumber : orderRecordIds) {
        if (!orderRecordIdToOrder.containsKey(orderNumber)) {
            newOrdersToInsert.add(new Order(
                External_Record_Id__c = orderNumber,
                AccountId = dummyAccount.Id,
                EffectiveDate = Date.today(),
                Pricebook2Id = standardPricebookId,
                Status = 'Draft'
            ));
        }
    }
    
    if (!newOrdersToInsert.isEmpty()) {
        insert newOrdersToInsert;
        for (Order odr : newOrdersToInsert) {
            orderRecordIdToOrder.put(odr.External_Record_Id__c, odr);
        }
    }

    // Create missing Products
    List<Product2> productsToInsert = new List<Product2>();
    for (Object record : records) {
        Map<String, Object> recordMap = (Map<String, Object>) record;
        Integer itemRecordId = (Integer) recordMap.get('Item_RecordID');
        String itemName = (String) recordMap.get('Item');
        String normalizedItemName = normalizeProductName(itemName);

        if (itemRecordId != null && 
            !itemRecordIdToProductId.containsKey((Decimal)itemRecordId) && 
            !itemNameToProductId.containsKey(normalizedItemName)) {
            productsToInsert.add(new Product2(
                Name = normalizedItemName,
                External_Record_Id__c = itemRecordId,
                IsActive = true
            ));
        }
    }

    if (!productsToInsert.isEmpty()) {
        insert productsToInsert;
        for (Product2 product : productsToInsert) {
            itemNameToProductId.put(product.Name, product.Id);
            if (product.External_Record_Id__c != null) {
                itemRecordIdToProductId.put(product.External_Record_Id__c, product.Id);
            }
        }
    }

    // Process Pricebook Entries
    Map<Id, Map<Id, Id>> pricebookIdToProductIdToPricebookEntryId = new Map<Id, Map<Id, Id>>();
    Set<Id> allProductIds = new Set<Id>();
    allProductIds.addAll(itemNameToProductId.values());
    allProductIds.addAll(itemRecordIdToProductId.values());

    for (PricebookEntry pbe : [
        SELECT Id, Product2Id, Pricebook2Id
        FROM PricebookEntry
        WHERE Product2Id IN :allProductIds AND Pricebook2Id = :standardPricebookId
    ]) {
        if (!pricebookIdToProductIdToPricebookEntryId.containsKey(pbe.Pricebook2Id)) {
            pricebookIdToProductIdToPricebookEntryId.put(pbe.Pricebook2Id, new Map<Id, Id>());
        }
        pricebookIdToProductIdToPricebookEntryId.get(pbe.Pricebook2Id).put(pbe.Product2Id, pbe.Id);
    }

    // Process Order Items - FIXED PRODUCT2ID ISSUE HERE
    List<OrderItem> itemsToInsert = new List<OrderItem>();
    List<OrderItem> itemsToUpdate = new List<OrderItem>();
    
    for (Object record : records) {
        Map<String, Object> recordMap = (Map<String, Object>) record;
        Integer extRecordId = (Integer) recordMap.get('RecordID');
        Integer orderRecordId = (Integer) recordMap.get('SalesOrderRecordID');
        String itemName = (String) recordMap.get('Item');
        String normalizedItemName = normalizeProductName(itemName);
        Integer itemRecordId = (Integer) recordMap.get('Item_RecordID');
        String chemicalName = (String) recordMap.get('ChemicalName'); // ✅ captured here

        if (existingOrderItemMap.containsKey(extRecordId)) {
            // For EXISTING items - only update writable fields
            OrderItem existingItem = existingOrderItemMap.get(extRecordId);
            
            existingItem.Quantity = (Decimal) recordMap.get('Quantity');
            existingItem.UnitPrice = (Decimal) recordMap.get('Rate');
            existingItem.TJ_Price__c = (Decimal) recordMap.get('TJPrice');
            existingItem.U_M__c = (String) recordMap.get('UnitofMeasurement');
            existingItem.Description = (String) recordMap.get('POService');
            existingItem.Line_Item_Change__c = String.valueOf(recordMap.get('Change'));
            existingItem.CCL_Number__c = (String) recordMap.get('CCLNumber');

            // 🔑 Compound mapping
            if (String.isNotBlank(chemicalName) && compoundNameToId.containsKey(chemicalName)) {
                existingItem.Compound__c = compoundNameToId.get(chemicalName);
                existingItem.Original_Compound__c = null;
            } else {
                existingItem.Compound__c = null;
                existingItem.Original_Compound__c = chemicalName;
            }

            // Handle invoiced flag
            Object invoicedValue = recordMap.get('Invoiced');
            Boolean isInvoiced = false;
            if (invoicedValue != null) {
                if (invoicedValue instanceof Boolean) {
                    isInvoiced = (Boolean) invoicedValue;
                } else if (invoicedValue instanceof String) {
                    isInvoiced = ((String)invoicedValue).toLowerCase() == 'true';
                } else if (invoicedValue instanceof Integer) {
                    isInvoiced = ((Integer)invoicedValue) == 1;
                }
            }
            existingItem.Invoiced__c = isInvoiced;

            itemsToUpdate.add(existingItem);
        } else {
            // For NEW items - set all required fields including non-writable ones
            Id productId = null;
            if (itemNameToProductId.containsKey(normalizedItemName)) {
                productId = itemNameToProductId.get(normalizedItemName);
            } else if (itemRecordId != null && itemRecordIdToProductId.containsKey((Decimal)itemRecordId)) {
                productId = itemRecordIdToProductId.get((Decimal)itemRecordId);
            }
            
            Decimal orderRecordDecimal;
            try {
                orderRecordDecimal = Decimal.valueOf(String.valueOf(recordMap.get('SalesOrderRecordID')));
            } catch (Exception e) {
                Logger.error('Unable to convert SalesOrderRecordID to Decimal: ' + recordMap.get('SalesOrderRecordID'));
                logger.saveLog();
                continue;
            }

            Id orderId = null;
            if (orderRecordIdToOrder.containsKey(orderRecordDecimal)) {
                orderId = orderRecordIdToOrder.get(orderRecordDecimal).Id;
            } else {
                Logger.error('Order not found in map for External_Record_Id__c = ' + orderRecordDecimal);
                logger.saveLog();
                continue;
            }
            
            Id pricebookEntryId = null;
            if (orderId != null && productId != null) {
                Order order = orderRecordIdToOrder.get((Decimal)orderRecordId);
                if (pricebookIdToProductIdToPricebookEntryId.containsKey(order.Pricebook2Id)) {
                    Map<Id, Id> productToPBE = pricebookIdToProductIdToPricebookEntryId.get(order.Pricebook2Id);
                    if (productToPBE.containsKey(productId)) {
                        pricebookEntryId = productToPBE.get(productId);
                    }
                }
            }
            
            if (productId != null && orderId != null && pricebookEntryId != null) {
                OrderItem newItem = new OrderItem(
                    External_Record_Id__c = extRecordId,
                    Product2Id = productId,
                    OrderId = orderId,
                    PricebookEntryId = pricebookEntryId,
                    Quantity = (Decimal) recordMap.get('Quantity'),
                    UnitPrice = (Decimal) recordMap.get('Rate'),
                    TJ_Price__c = (Decimal) recordMap.get('TJPrice'),
                    U_M__c = (String) recordMap.get('UnitofMeasurement'), 
                    Invoiced__c = (Boolean) recordMap.get('Closed'),
                    Description = (String) recordMap.get('POService'),
                    Line_Item_Change__c = String.valueOf(recordMap.get('Change')),
                    CCL_Number__c = (String) recordMap.get('CCLNumber')
                );

                // 🔑 Compound mapping
                if (String.isNotBlank(chemicalName) && compoundNameToId.containsKey(chemicalName)) {
                    newItem.Compound__c = compoundNameToId.get(chemicalName);
                    newItem.Original_Compound__c = null;
                } else {
                    newItem.Compound__c = null;
                    newItem.Original_Compound__c = chemicalName;
                }

                itemsToInsert.add(newItem);
            }
        }
    }

    // Perform DML operations
    if (!itemsToInsert.isEmpty()) {
        insert itemsToInsert;
    }
    if (!itemsToUpdate.isEmpty()) {
        update itemsToUpdate;
    }
}


  /**
   * @description Helper method to normalize product names for consistency
   * @param itemName Raw item name from API
   * @return Normalized product name
   */
  public static String normalizeProductName(String itemName) {
    if (String.isBlank(itemName)) {
      return null;
    }

    // Handle specific normalization cases
    String normalized = itemName.trim();
    if (normalized.equalsIgnoreCase('R & D')) {
      return 'R&D';
    }

    return normalized;
  }

  /**
   * @description Wrapper class for sync type options
   */
  public class SyncTypeOption {
    @AuraEnabled
    public String label { get; set; }
    @AuraEnabled
    public String value { get; set; }
    @AuraEnabled
    public String description { get; set; }

    public SyncTypeOption(String label, String value, String description) {
      this.label = label;
      this.value = value;
      this.description = description;
    }
  }

  /**
   * @description Wrapper class for sync results
   */
  public class SyncResult {
    @AuraEnabled
    public Boolean hasError { get; set; }
    @AuraEnabled
    public String message { get; set; }
    @AuraEnabled
    public String jobId { get; set; }

    public SyncResult(Boolean hasError, String message, String jobId) {
      this.hasError = hasError;
      this.message = message;
      this.jobId = jobId;
    }
  }
}