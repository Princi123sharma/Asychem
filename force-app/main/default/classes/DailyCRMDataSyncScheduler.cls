/**
 * @description Optimized Daily CRM Data Sync Scheduler
 * @author Optimized by AI Assistant
 * @date 2025
 */
global class DailyCRMDataSyncScheduler implements Schedulable {

    // Constants for configuration
    private static final String API_BASE_URL = 'https://rest.method.me';
    private static final String API_KEY = 'NjdmNjBiNGMxODQwNmI5YTI3NTdlOWY5LjkyQzA2QUY0QzlEMzQxQ0E4QzRGOEE5REZBNDNEQjk2'; // TODO: Move to Custom Settings
    private static final Integer BATCH_SIZE = 200;
    private static final Integer MAX_CALLOUT_RETRIES = 3;

    // Default date range for data sync (yesterday's data)
    private static final DateTime DEFAULT_SYNC_START_TIME = DateTime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0));
    private static final DateTime DEFAULT_SYNC_END_TIME = DateTime.newInstance(Date.today(), Time.newInstance(23, 59, 59, 0));

    /**
     * @description Main execution method for the scheduler
     * @param sc SchedulableContext
     */
    global void execute(SchedulableContext sc) {
        try {
            System.debug('Starting Daily CRM Data Sync at: ' + DateTime.now());

            // Execute sync operations in sequence using default date range
            fetchAndProcessSalesOrders(DEFAULT_SYNC_START_TIME, DEFAULT_SYNC_END_TIME);
            fetchAndProcessInvoices(DEFAULT_SYNC_START_TIME, DEFAULT_SYNC_END_TIME);
            fetchAndProcessBills(DEFAULT_SYNC_START_TIME, DEFAULT_SYNC_END_TIME);
            fetchAndProcessInvoiceProducts(DEFAULT_SYNC_START_TIME, DEFAULT_SYNC_END_TIME);
            fetchAndProcessSalesOrderLines(DEFAULT_SYNC_START_TIME, DEFAULT_SYNC_END_TIME);

            System.debug('Completed Daily CRM Data Sync at: ' + DateTime.now());
        } catch (Exception e) {
            System.debug('Critical error in Daily CRM Data Sync: ' + e.getMessage() + '\n' + e.getStackTraceString());
            // TODO: Send notification to administrators
        }
    }

    /**
     * @description Public method to sync all data types with custom date range
     * @param startTime Start date and time for sync
     * @param endTime End date and time for sync
     */
    public static void methodsyncAll(DateTime startTime, DateTime endTime) {
        try {
            System.debug('Starting methodsyncAll at: ' + DateTime.now() + ' for date range: ' + startTime + ' to ' + endTime);

            // Execute sync operations in sequence
            methodsyncSalesOrders(startTime, endTime);
            methodsyncInvoices(startTime, endTime);
            methodsyncBills(startTime, endTime);
            methodsyncInvoiceProducts(startTime, endTime);
            methodsyncSalesOrderLines(startTime, endTime);

            System.debug('Completed methodsyncAll at: ' + DateTime.now());
        } catch (Exception e) {
            System.debug('Critical error in methodsyncAll: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw e;
        }
    }

    /**
     * @description Public method to sync all data types with default date range (yesterday)
     */
    public static void methodsyncAll() {
        methodsyncAll(DEFAULT_SYNC_START_TIME, DEFAULT_SYNC_END_TIME);
    }

    /**
     * @description Public method to sync Sales Orders with custom date range
     * @param startTime Start date and time for sync
     * @param endTime End date and time for sync
     */
    public static void methodsyncSalesOrders(DateTime startTime, DateTime endTime) {
        try {
            System.debug('Starting methodsyncSalesOrders at: ' + DateTime.now());
            List<Object> records = performHttpCallout('salesorder', startTime, endTime);
            if (!records.isEmpty()) {
                processSalesOrderData(records);
            }
            System.debug('Completed methodsyncSalesOrders at: ' + DateTime.now());
        } catch (Exception e) {
            System.debug('Error in methodsyncSalesOrders: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw e;
        }
    }

    /**
     * @description Public method to sync Sales Orders with default date range
     */
    public static void methodsyncSalesOrders() {
        methodsyncSalesOrders(DEFAULT_SYNC_START_TIME, DEFAULT_SYNC_END_TIME);
    }

    /**
     * @description Public method to sync Invoices with custom date range
     * @param startTime Start date and time for sync
     * @param endTime End date and time for sync
     */
    public static void methodsyncInvoices(DateTime startTime, DateTime endTime) {
        try {
            System.debug('Starting methodsyncInvoices at: ' + DateTime.now());
            List<Object> records = performHttpCallout('invoice', startTime, endTime);
            if (!records.isEmpty()) {
                processInvoiceData(records);
            }
            System.debug('Completed methodsyncInvoices at: ' + DateTime.now());
        } catch (Exception e) {
            System.debug('Error in methodsyncInvoices: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw e;
        }
    }

    /**
     * @description Public method to sync Invoices with default date range
     */
    public static void methodsyncInvoices() {
        methodsyncInvoices(DEFAULT_SYNC_START_TIME, DEFAULT_SYNC_END_TIME);
    }

    /**
     * @description Public method to sync Bills with custom date range
     * @param startTime Start date and time for sync
     * @param endTime End date and time for sync
     */
    public static void methodsyncBills(DateTime startTime, DateTime endTime) {
        try {
            System.debug('Starting methodsyncBills at: ' + DateTime.now());
            List<Object> records = performHttpCallout('bill', startTime, endTime);
            if (!records.isEmpty()) {
                processBillData(records);
            }
            System.debug('Completed methodsyncBills at: ' + DateTime.now());
        } catch (Exception e) {
            System.debug('Error in methodsyncBills: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw e;
        }
    }

    /**
     * @description Public method to sync Bills with default date range
     */
    public static void methodsyncBills() {
        methodsyncBills(DEFAULT_SYNC_START_TIME, DEFAULT_SYNC_END_TIME);
    }

    /**
     * @description Public method to sync Invoice Products with custom date range
     * @param startTime Start date and time for sync
     * @param endTime End date and time for sync
     */
    public static void methodsyncInvoiceProducts(DateTime startTime, DateTime endTime) {
        try {
            System.debug('Starting methodsyncInvoiceProducts at: ' + DateTime.now());
            List<Object> records = performHttpCallout('InvoiceLine', startTime, endTime);
            if (!records.isEmpty()) {
                processInvoiceProductData(records);
            }
            System.debug('Completed methodsyncInvoiceProducts at: ' + DateTime.now());
        } catch (Exception e) {
            System.debug('Error in methodsyncInvoiceProducts: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw e;
        }
    }

    /**
     * @description Public method to sync Invoice Products with default date range
     */
    public static void methodsyncInvoiceProducts() {
        methodsyncInvoiceProducts(DEFAULT_SYNC_START_TIME, DEFAULT_SYNC_END_TIME);
    }

    /**
     * @description Public method to sync Sales Order Lines with custom date range
     * @param startTime Start date and time for sync
     * @param endTime End date and time for sync
     */
    public static void methodsyncSalesOrderLines(DateTime startTime, DateTime endTime) {
        try {
            System.debug('Starting methodsyncSalesOrderLines at: ' + DateTime.now());
            List<Object> records = performHttpCallout('SalesOrderLine', startTime, endTime);
            if (!records.isEmpty()) {
                processSalesOrderLineData(records);
            }
            System.debug('Completed methodsyncSalesOrderLines at: ' + DateTime.now());
        } catch (Exception e) {
            System.debug('Error in methodsyncSalesOrderLines: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw e;
        }
    }

    /**
     * @description Public method to sync Sales Order Lines with default date range
     */
    public static void methodsyncSalesOrderLines() {
        methodsyncSalesOrderLines(DEFAULT_SYNC_START_TIME, DEFAULT_SYNC_END_TIME);
    }

    /**
     * @description Utility method to perform HTTP callouts with pagination
     * @param tableName The table name to fetch data from
     * @param startTime Start date and time for filtering
     * @param endTime End date and time for filtering
     * @return List of records fetched from the API
     */
    private static List<Object> performHttpCallout(String tableName, DateTime startTime, DateTime endTime) {
        String endpoint = API_BASE_URL + '/api/v1/tables/' + tableName;
        String filter = buildDateFilter(startTime, endTime);
        String fullEndpoint = endpoint + '?filter=' + EncodingUtil.urlEncode(filter, 'UTF-8');

        List<Object> allRecords = new List<Object>();
        String nextUrl = fullEndpoint;
        Http http = new Http();
        Integer calloutCount = 0;

        try {
            while (String.isNotBlank(nextUrl) && calloutCount < MAX_CALLOUT_RETRIES) {
                HttpRequest req = buildHttpRequest(nextUrl);
                HttpResponse res = http.send(req);
                calloutCount++;

                if (res.getStatusCode() == 200) {
                    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

                    // Extract records from response
                    List<Object> records = (List<Object>) JSON.deserializeUntyped(JSON.serialize(responseMap.get('value')));
                    if (records != null) {
                        allRecords.addAll(records);
                    }

                    // Handle pagination
                    nextUrl = buildNextUrl((String) responseMap.get('nextLink'));
                } else {
                    System.debug('HTTP Error ' + res.getStatusCode() + ' for ' + tableName + ': ' + res.getBody());
                    break;
                }

                // Governor limit check
                if (Limits.getCallouts() >= Limits.getLimitCallouts() - 5) {
                    System.debug('Approaching callout limit, stopping pagination for ' + tableName);
                    break;
                }
            }

            System.debug('Fetched ' + allRecords.size() + ' records from ' + tableName);
            return allRecords;

        } catch (Exception e) {
            System.debug('Exception fetching data from ' + tableName + ': ' + e.getMessage() + '\n' + e.getStackTraceString());
            return new List<Object>();
        }
    }

    /**
     * @description Builds the date filter for API calls with custom date range
     * @param startTime Start date and time for filtering
     * @param endTime End date and time for filtering
     * @return Formatted date filter string
     */
    public static String buildDateFilter(DateTime startTime, DateTime endTime) {
        return 'LastModifiedDate ge \'' + startTime.format('yyyy-MM-dd\'T\'HH:mm:ss') +
               '\' and LastModifiedDate lt \'' + endTime.format('yyyy-MM-dd\'T\'HH:mm:ss') + '\'';
    }

    /**
     * @description Builds the date filter for API calls with default date range
     * @return Formatted date filter string
     */
    public static String buildDateFilter() {
        return buildDateFilter(DEFAULT_SYNC_START_TIME, DEFAULT_SYNC_END_TIME);
    }

    /**
     * @description Builds HTTP request with proper headers
     * @param endpoint The endpoint URL
     * @return Configured HttpRequest
     */
    private static HttpRequest buildHttpRequest(String endpoint) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Authorization', 'APIKey ' + API_KEY);
        req.setTimeout(60000); // 60 seconds timeout
        return req;
    }

    /**
     * @description Builds the next URL for pagination
     * @param nextLink The next link from API response
     * @return Properly formatted next URL or null
     */
    private static String buildNextUrl(String nextLink) {
        if (String.isBlank(nextLink)) {
            return null;
        }

        if (!nextLink.startsWith('https')) {
            return API_BASE_URL + nextLink;
        }

        return nextLink;
    }

    /**
     * @description Fetch and process Sales Order Lines with custom date range
     * @param startTime Start date and time for sync
     * @param endTime End date and time for sync
     */
    @future(callout=true)
    private static void fetchAndProcessSalesOrderLines(DateTime startTime, DateTime endTime) {
        List<Object> records = performHttpCallout('SalesOrderLine', startTime, endTime);
        if (!records.isEmpty()) {
            processSalesOrderLineData(records);
        }
    }

    /**
     * @description Fetch and process Invoice Products with custom date range
     * @param startTime Start date and time for sync
     * @param endTime End date and time for sync
     */
    @future(callout=true)
    private static void fetchAndProcessInvoiceProducts(DateTime startTime, DateTime endTime) {
        List<Object> records = performHttpCallout('InvoiceLine', startTime, endTime);
        if (!records.isEmpty()) {
            processInvoiceProductData(records);
        }
    }

    /**
     * @description Fetch and process Sales Orders with custom date range
     * @param startTime Start date and time for sync
     * @param endTime End date and time for sync
     */
    @future(callout=true)
    private static void fetchAndProcessSalesOrders(DateTime startTime, DateTime endTime) {
        List<Object> records = performHttpCallout('salesorder', startTime, endTime);
        if (!records.isEmpty()) {
            processSalesOrderData(records);
        }
    }

    /**
     * @description Fetch and process Invoices with custom date range
     * @param startTime Start date and time for sync
     * @param endTime End date and time for sync
     */
    @future(callout=true)
    private static void fetchAndProcessInvoices(DateTime startTime, DateTime endTime) {
        List<Object> records = performHttpCallout('invoice', startTime, endTime);
        if (!records.isEmpty()) {
            processInvoiceData(records);
        }
    }

    /**
     * @description Fetch and process Bills with custom date range
     * @param startTime Start date and time for sync
     * @param endTime End date and time for sync
     */
    @future(callout=true)
    private static void fetchAndProcessBills(DateTime startTime, DateTime endTime) {
        List<Object> records = performHttpCallout('bill', startTime, endTime);
        if (!records.isEmpty()) {
            processBillData(records);
        }
    }

    /**
     * @description Process Sales Order data with optimized bulk operations
     * @param records List of sales order records from API
     */
    public static void processSalesOrderData(List<Object> records) {
        if (records == null || records.isEmpty()) {
            System.debug('No Sales Order records to process');
            return;
        }

        System.debug('Processing ' + records.size() + ' Sales Order records');

        // Initialize collections
        List<Order> ordersToUpsert = new List<Order>();
        Set<String> customerNames = new Set<String>();
        Set<Integer> extRecordIds = new Set<Integer>();

        // Extract data from records
        try {
            for (Object record : records) {
                Map<String, Object> recordMap = (Map<String, Object>) record;
                if (recordMap == null) continue;

                Integer extRecordId = (Integer) recordMap.get('RecordID');
                String customerName = (String) recordMap.get('Customer');

                if (extRecordId != null) {
                    extRecordIds.add(extRecordId);
                }

                if (String.isNotBlank(customerName)) {
                    customerNames.add(customerName);
                }
            }
        } catch (Exception e) {
            System.debug('Error extracting data from Sales Order records: ' + e.getMessage());
            return;
        }

        // Query existing orders
        Map<Decimal, Order> existingOrdersMap = new Map<Decimal, Order>();
        try {
            for (Order existingOrder : [
                SELECT Id, AccountId, GMP_Requirements__c, PO_Type__c, Supplier__c, US_Tech__c,
                PCO__c, Lead_Time__c, External_Record_Id__c, Status, Client_PO_Number__c,
                EffectiveDate, EndDate, Ext_Internal_PO__c, Customer_Delivery_Terms__c
                FROM Order
                WHERE External_Record_Id__c IN :extRecordIds
                LIMIT 10000
            ]) {
                existingOrdersMap.put(existingOrder.External_Record_Id__c, existingOrder);
            }
        } catch (Exception e) {
            System.debug('Error querying existing orders: ' + e.getMessage());
        }

        // Query existing accounts
        Map<String, Id> customerNameToAccountId = getOrCreateAccounts(customerNames);

        // Process each record and create/update orders
        try {
            for (Object record : records) {
                Map<String, Object> recordMap = (Map<String, Object>) record;
                if (recordMap == null) continue;

                Order order = processIndividualSalesOrder(recordMap, existingOrdersMap, customerNameToAccountId);
                if (order != null) {
                    ordersToUpsert.add(order);
                }

                // Batch processing to avoid memory issues
                if (ordersToUpsert.size() >= BATCH_SIZE) {
                    upsertOrders(ordersToUpsert);
                    ordersToUpsert.clear();
                }
            }

            // Process remaining orders
            if (!ordersToUpsert.isEmpty()) {
                upsertOrders(ordersToUpsert);
            }

        } catch (Exception e) {
            System.debug('Error processing Sales Order records: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }

    /**
     * @description Get or create accounts for customer names
     * @param customerNames Set of customer names
     * @return Map of customer name to account ID
     */
    public static Map<String, Id> getOrCreateAccounts(Set<String> customerNames) {
        Map<String, Id> customerNameToAccountId = new Map<String, Id>();
        List<Account> accountsToInsert = new List<Account>();

        // Query existing accounts
        try {
            for (Account acc : [SELECT Id, Name FROM Account WHERE Name IN :customerNames LIMIT 10000]) {
                customerNameToAccountId.put(acc.Name, acc.Id);
            }
        } catch (Exception e) {
            System.debug('Error querying existing accounts: ' + e.getMessage());
        }

        // Create missing accounts
        Map<String, Integer> nickNameCounterMap = new Map<String, Integer>();
        for (String customerName : customerNames) {
            if (!customerNameToAccountId.containsKey(customerName)) {
                String nickName = generateNickName(customerName, nickNameCounterMap);
                accountsToInsert.add(new Account(
                    Name = customerName,
                    Nick_Name__c = nickName,
                    Description = 'Auto-created for Sales Order sync on ' + Date.today().format()
                ));
            }
        }

        // Insert new accounts
        if (!accountsToInsert.isEmpty()) {
            try {
                insert accountsToInsert;
                for (Account acc : accountsToInsert) {
                    customerNameToAccountId.put(acc.Name, acc.Id);
                }
                System.debug('Created ' + accountsToInsert.size() + ' new accounts');
            } catch (Exception ex) {
                System.debug('Error inserting accounts: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
            }
        }

        return customerNameToAccountId;
    }

    /**
     * @description Generate unique nickname for account
     * @param customerName Customer name
     * @param nickNameCounterMap Counter map for nicknames
     * @return Generated nickname
     */
    private static String generateNickName(String customerName, Map<String, Integer> nickNameCounterMap) {
        String baseNickName = customerName.length() >= 3 ? customerName.substring(0, 3) : customerName;
        String nickName = baseNickName;

        if (nickNameCounterMap.containsKey(baseNickName)) {
            nickNameCounterMap.put(baseNickName, nickNameCounterMap.get(baseNickName) + 1);
            nickName = baseNickName + nickNameCounterMap.get(baseNickName);
        } else {
            nickNameCounterMap.put(baseNickName, 1);
        }

        return nickName;
    }

    /**
     * @description Process individual sales order record
     * @param recordMap Sales order record data
     * @param existingOrdersMap Map of existing orders
     * @param customerNameToAccountId Map of customer names to account IDs
     * @return Processed Order or null if invalid
     */
    private static Order processIndividualSalesOrder(Map<String, Object> recordMap,
                                                   Map<Decimal, Order> existingOrdersMap,
                                                   Map<String, Id> customerNameToAccountId) {
        try {
            Integer extRecordId = (Integer) recordMap.get('RecordID');
            String customerName = (String) recordMap.get('Customer');

            if (extRecordId == null || String.isBlank(customerName)) {
                System.debug('Skipping order with missing RecordID or Customer');
                return null;
            }

            // Get or create order
            Order order;
            if (existingOrdersMap.containsKey(extRecordId)) {
                order = existingOrdersMap.get(extRecordId);
            } else {
                order = new Order(External_Record_Id__c = extRecordId);
                if (customerNameToAccountId.containsKey(customerName)) {
                    order.AccountId = customerNameToAccountId.get(customerName);
                } else {
                    System.debug('No Account found for customer: ' + customerName);
                    return null;
                }
            }

            // Map fields with null checks and validation
            order.Name = customerName;
            order.Status = 'Draft';

            // Handle dates with proper validation
            order.EndDate = parseEndDate(recordMap);
            order.EffectiveDate = parseEffectiveDate(recordMap);

            // Map other fields
            order.Client_PO_Number__c = (String) recordMap.get('PONumber');
            order.PO_Type__c = (String) recordMap.get('POType');
            order.Lead_Time__c = (String) recordMap.get('TotalLeadTime');
            order.Ext_Internal_PO__c = (String) recordMap.get('RefNumber');
            order.Customer_Delivery_Terms__c = (String) recordMap.get('CustomerDeliveryTerms');
            order.PCO__c = (String) recordMap.get('TJProjContact');
            order.US_Tech__c = (String) recordMap.get('USATechContact');
            //order.GMP_Requirements__c = (String) recordMap.get('GMPStatus');

            // Handle supplier mapping
            String supplierValue = mapSupplierValue((String) recordMap.get('Location'));
            if (supplierValue != null) {
                order.Supplier__c = supplierValue;
            }

            return order;

        } catch (Exception e) {
            System.debug('Error processing individual sales order: ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description Parse end date from record map
     * @param recordMap Record data
     * @return Parsed end date or default
     */
    private static Date parseEndDate(Map<String, Object> recordMap) {
        try {
            String tjDueDate = (String) recordMap.get('TJDueDate1');
            if (String.isNotBlank(tjDueDate)) {
                Date potentialEndDate = Date.valueOf(tjDueDate);
                return potentialEndDate >= Date.today() ? potentialEndDate : Date.today();
            }
        } catch (Exception e) {
            System.debug('Error parsing TJDueDate1: ' + e.getMessage());
        }
        return Date.today().addDays(1);
    }

    /**
     * @description Parse effective date from record map
     * @param recordMap Record data
     * @return Parsed effective date or today
     */
    private static Date parseEffectiveDate(Map<String, Object> recordMap) {
        try {
            String txnDate = (String) recordMap.get('TxnDate');
            if (String.isNotBlank(txnDate)) {
                return Date.valueOf(txnDate);
            }
        } catch (Exception e) {
            System.debug('Error parsing TxnDate: ' + e.getMessage());
        }
        return Date.today();
    }

    /**
     * @description Map supplier location to valid picklist value
     * @param location Raw location value
     * @return Mapped supplier value or null
     */
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
    private static void upsertOrders(List<Order> orders) {
        if (orders == null || orders.isEmpty()) {
            return;
        }

        try {
            upsert orders External_Record_Id__c;
            System.debug('Successfully upserted ' + orders.size() + ' orders');
        } catch (DmlException e) {
            System.debug('DML Error upserting orders: ' + e.getMessage());
            for (Integer i = 0; i < e.getNumDml(); i++) {
                System.debug('DML Error on record ' + i + ': ' + e.getDmlMessage(i));
            }
        } catch (Exception e) {
            System.debug('Unexpected error upserting orders: ' + e.getMessage() + '\n' + e.getStackTraceString());
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
                SELECT Id, External_Record_Id__c, AVSFQB__Invoice_Number__c, Client_Name__c,
                AVSFQB__TxnDate__c, P_O__c, Issued_by__c, S_O__c, Type__c
                FROM AVSFQB__Invoices__c
                WHERE External_Record_Id__c IN :extRecordIds
                LIMIT 10000
            ]) {
                existingInvoicesMap.put(existingInvoice.External_Record_Id__c, existingInvoice);
            }
        } catch (Exception e) {
            System.debug('Error querying existing invoices: ' + e.getMessage());
        }

        // Process records
        try {
            for (Object record : records) {
                Map<String, Object> recordMap = (Map<String, Object>) record;
                Integer extRecordId = (Integer) recordMap.get('RecordID');

                if (extRecordId == null || recordIdToInvoiceMap.containsKey(extRecordId)) {
                    continue; // Skip duplicate or null ID
                }

                AVSFQB__Invoices__c invoice = processIndividualInvoice(recordMap, existingInvoicesMap);
                if (invoice != null) {
                    recordIdToInvoiceMap.put(extRecordId, invoice);
                }
            }

            // Upsert invoices
            if (!recordIdToInvoiceMap.isEmpty()) {
                upsertInvoices(new List<AVSFQB__Invoices__c>(recordIdToInvoiceMap.values()));
            }

        } catch (Exception ex) {
            System.debug('Error processing Invoice records: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
        }
    }

    /**
     * @description Process individual invoice record
     * @param recordMap Invoice record data
     * @param existingInvoicesMap Map of existing invoices
     * @return Processed Invoice or null if invalid
     */
    private static AVSFQB__Invoices__c processIndividualInvoice(Map<String, Object> recordMap,
                                                              Map<Decimal, AVSFQB__Invoices__c> existingInvoicesMap) {
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

            // Handle date parsing
            try {
                String txnDate = (String) recordMap.get('TxnDate');
                if (String.isNotBlank(txnDate)) {
                    invoice.AVSFQB__TxnDate__c = Date.valueOf(txnDate);
                }
            } catch (Exception e) {
                System.debug('Error parsing TxnDate for invoice ' + extRecordId + ': ' + e.getMessage());
                invoice.AVSFQB__TxnDate__c = Date.today();
            }

            return invoice;

        } catch (Exception e) {
            System.debug('Error processing individual invoice: ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description Upsert invoices with error handling
     * @param invoices List of invoices to upsert
     */
    private static void upsertInvoices(List<AVSFQB__Invoices__c> invoices) {
        if (invoices == null || invoices.isEmpty()) {
            return;
        }

        try {
            upsert invoices External_Record_Id__c;
            System.debug('Successfully upserted ' + invoices.size() + ' invoices');
        } catch (DmlException e) {
            System.debug('DML Error upserting invoices: ' + e.getMessage());
            for (Integer i = 0; i < e.getNumDml(); i++) {
                System.debug('DML Error on record ' + i + ': ' + e.getDmlMessage(i));
            }
        } catch (Exception e) {
            System.debug('Unexpected error upserting invoices: ' + e.getMessage() + '\n' + e.getStackTraceString());
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
                SELECT Id, External_Record_Id__c, AVSFQB__Invoice_Number__c, Client_Name__c,
                AVSFQB__TxnDate__c, AVSFQB__Total_Invoice_Amount__c, Type__c
                FROM AVSFQB__Invoices__c
                WHERE External_Record_Id__c IN :billNumbers
                LIMIT 10000
            ]) {
                existingBillsMap.put(existingBill.External_Record_Id__c, existingBill);
            }
        } catch (Exception e) {
            System.debug('Error querying existing bills: ' + e.getMessage());
        }

        // Process records
        try {
            for (Object record : records) {
                Map<String, Object> recordMap = (Map<String, Object>) record;
                AVSFQB__Invoices__c bill = processIndividualBill(recordMap, existingBillsMap);
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
            System.debug('Error processing Bill records: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
        }
    }

    /**
     * @description Process individual bill record
     * @param recordMap Bill record data
     * @param existingBillsMap Map of existing bills
     * @return Processed Bill or null if invalid
     */
    private static AVSFQB__Invoices__c processIndividualBill(Map<String, Object> recordMap,
                                                           Map<Decimal, AVSFQB__Invoices__c> existingBillsMap) {
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
                System.debug('Error parsing TxnDate for bill ' + billNumber + ': ' + e.getMessage());
                bill.AVSFQB__TxnDate__c = Date.today();
            }

            return bill;

        } catch (Exception e) {
            System.debug('Error processing individual bill: ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description Upsert bills with error handling
     * @param bills List of bills to upsert
     */
    private static void upsertBills(List<AVSFQB__Invoices__c> bills) {
        if (bills == null || bills.isEmpty()) {
            return;
        }

        try {
            upsert bills External_Record_Id__c;
            System.debug('Successfully upserted ' + bills.size() + ' bills');
        } catch (DmlException e) {
            System.debug('DML Error upserting bills: ' + e.getMessage());
            for (Integer i = 0; i < e.getNumDml(); i++) {
                System.debug('DML Error on record ' + i + ': ' + e.getDmlMessage(i));
            }
        } catch (Exception e) {
            System.debug('Unexpected error upserting bills: ' + e.getMessage() + '\n' + e.getStackTraceString());
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
                SELECT Id, Name, Invoice__c, CCL_Number__c, Compound__c, Quantity__c,
                Unit_Price__c, Total_Price__c, QB_Item_Class__c, External_Record_Id__c, PO_Service_Activity__c
                FROM Invoice_Products__c
                WHERE External_Record_Id__c IN :extRecordIds
                LIMIT 10000
            ]) {
                existingProductsMap.put(existingProduct.External_Record_Id__c, existingProduct);
            }
        } catch (Exception e) {
            System.debug('Error querying existing invoice products: ' + e.getMessage());
        }

        // Get or create invoice mappings
        Map<Decimal, Id> invoiceNumberToId = getOrCreateInvoices(invoiceNumbers);

        // Process records
        List<Invoice_Products__c> productsToUpsert = new List<Invoice_Products__c>();
        try {
            for (Object record : records) {
                Map<String, Object> recordMap = (Map<String, Object>) record;
                Invoice_Products__c product = processIndividualInvoiceProduct(recordMap, existingProductsMap, invoiceNumberToId);
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
            System.debug('Error processing Invoice Product records: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
        }
    }

    /**
     * @description Get or create invoices for invoice numbers
     * @param invoiceNumbers Set of invoice numbers
     * @return Map of invoice number to invoice ID
     */
    private static Map<Decimal, Id> getOrCreateInvoices(Set<Integer> invoiceNumbers) {
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
            System.debug('Error querying existing invoices: ' + e.getMessage());
        }

        // Create missing invoices
        for (Integer invoiceNumber : invoiceNumbers) {
            if (!invoiceNumberToId.containsKey(invoiceNumber)) {
                invoicesToInsert.add(new AVSFQB__Invoices__c(
                    External_Record_Id__c = invoiceNumber,
                    Type__c = 'Invoice'
                ));
            }
        }

        // Insert new invoices
        if (!invoicesToInsert.isEmpty()) {
            try {
                insert invoicesToInsert;
                for (AVSFQB__Invoices__c inv : invoicesToInsert) {
                    invoiceNumberToId.put(inv.External_Record_Id__c, inv.Id);
                }
                System.debug('Created ' + invoicesToInsert.size() + ' placeholder invoices');
            } catch (Exception ex) {
                System.debug('Error inserting placeholder invoices: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
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
    private static Invoice_Products__c processIndividualInvoiceProduct(Map<String, Object> recordMap,
                                                                     Map<Decimal, Invoice_Products__c> existingProductsMap,
                                                                     Map<Decimal, Id> invoiceNumberToId) {
        try {
            Integer extRecordId = (Integer) recordMap.get('RecordID');
            Integer invoiceNumber = (Integer) recordMap.get('InvoiceRecordID');

            if (extRecordId == null || invoiceNumber == null) {
                System.debug('Skipping invoice product with missing RecordID or InvoiceRecordID');
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
            System.debug('Error processing individual invoice product: ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description Upsert invoice products with error handling
     * @param products List of invoice products to upsert
     */
    private static void upsertInvoiceProducts(List<Invoice_Products__c> products) {
        if (products == null || products.isEmpty()) {
            return;
        }

        try {
            upsert products External_Record_Id__c;
            System.debug('Successfully upserted ' + products.size() + ' invoice products');
        } catch (DmlException e) {
            System.debug('DML Error upserting invoice products: ' + e.getMessage());
            for (Integer i = 0; i < e.getNumDml(); i++) {
                System.debug('DML Error on record ' + i + ': ' + e.getDmlMessage(i));
            }
        } catch (Exception e) {
            System.debug('Unexpected error upserting invoice products: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }


    /**
     * @description Process Sales Order Line data with complex product and pricebook management
     * @param records List of sales order line records from API
     */
    private static void processSalesOrderLineData(List<Object> records) {
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

                if (extRecordId != null) {
                    extRecordIds.add(extRecordId);
                }
                if (String.isNotBlank(chemicalName)) {
                    chemicalNames.add(chemicalName);
                }
                if (itemRecordId != null) {
                    itemRecordIds.add((Decimal) itemRecordId);
                }
                if (orderRecordId != null) {
                    orderRecordIds.add((Decimal) orderRecordId);
                }
                if (String.isNotBlank(itemName)) {
                    itemNames.add(normalizeProductName(itemName));
                }
            }
        } catch (Exception e) {
            System.debug('Error extracting data from Sales Order Line records: ' + e.getMessage());
            return;
        }

        System.debug('Extracted data - Chemicals: ' + chemicalNames.size() +
                     ', Items: ' + itemNames.size() + ', Orders: ' + orderRecordIds.size());

    // Query existing Order Line Item record
    Map<Decimal, OrderItem> existingOrderItemMap = new Map<Decimal, OrderItem>();
    for (OrderItem existingOrderItem : [
        SELECT Id, Description, External_Record_Id__c, Invoiced__c, U_M__c, UnitPrice, Quantity,
        TJ_Price__c, CCL_Number__c, Compound__c, Product2Id, OrderId, PricebookEntryId, 
        Line_Item_Change__c FROM OrderItem
        WHERE External_Record_Id__c IN :extRecordIds
    ]) {
        existingOrderItemMap.put(existingOrderItem.External_Record_Id__c, existingOrderItem);
    }

    // Query existing Compounds
    Map<String, Id> chemicalNameToId = new Map<String, Id>();
    for (Compound__c compound : [SELECT Id, Name FROM Compound__c WHERE Name IN :chemicalNames]) {
        chemicalNameToId.put(compound.Name, compound.Id);
    }

    // Query existing Products
    Map<String, Id> itemNameToProductId = new Map<String, Id>();
    Map<Decimal, Id> itemRecordIdToProductId = new Map<Decimal, Id>();
    for (Product2 product : [SELECT Id, Name, External_Record_Id__c FROM Product2 WHERE Name IN :itemNames OR External_Record_Id__c IN :itemRecordIds]) {
        itemNameToProductId.put(product.Name, product.Id);
        if (product.External_Record_Id__c != null) {
            itemRecordIdToProductId.put(product.External_Record_Id__c, product.Id);
        }
    }

    // Query existing Orders and ensure Pricebook2Id is set
    Map<Decimal, Order> orderRecordIdToOrder = new Map<Decimal, Order>();
    List<Order> ordersToUpdate = new List<Order>();
    Id standardPricebookId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
    for (Order order : [SELECT Id, External_Record_Id__c, Pricebook2Id FROM Order WHERE External_Record_Id__c IN :orderRecordIds]) {
        if (order.Pricebook2Id == null) {
            order.Pricebook2Id = standardPricebookId;
            ordersToUpdate.add(order);
        }
        orderRecordIdToOrder.put(order.External_Record_Id__c, order);
    }

    // Update Orders with missing Pricebook2Id
    if (!ordersToUpdate.isEmpty()) {
        try {
            update ordersToUpdate;
            System.debug('Updated ' + ordersToUpdate.size() + ' Orders with Standard Pricebook');
        } catch (Exception ex) {
            System.debug('Error updating Orders with Pricebook2Id: ' + ex.getMessage() + ' ' + ex.getStackTraceString());
        }
    }

    // Ensure dummy Account exists
    Account acc;
    List<Account> accounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'create dummy acc' LIMIT 1];
    if (!accounts.isEmpty()) {
        acc = accounts[0];
    } else {
        acc = new Account(Name = 'create dummy acc', Nick_Name__c = 'create dummy');
        try {
            insert acc;
        } catch (Exception ex) {
            System.debug('Error inserting dummy Account: ' + ex.getMessage() + ' ' + ex.getStackTraceString());
        }
    }

    // Create dummy order for non-existing External_Record_Id__c
    for (Decimal orderNumber : orderRecordIds) {
        if (!orderRecordIdToOrder.containsKey(orderNumber)) {
            ordersToUpdate.add(new Order(
                External_Record_Id__c = orderNumber,
                AccountId = acc.Id,
                EffectiveDate = Date.today(),
                Pricebook2Id = standardPricebookId,
                Status = 'Draft'
            ));
        }
    }
    
    // Insert new Orders
    if (!ordersToUpdate.isEmpty()) {
        try {
            insert ordersToUpdate;
            for (Order odr : ordersToUpdate) {
                orderRecordIdToOrder.put(odr.External_Record_Id__c, odr);
            }
        } catch (Exception ex) {
            System.debug('Error inserting dummy order: ' + ex.getMessage() + ' ' + ex.getStackTraceString());
        }
    }

    // Determine Pricebook2Id
    Map<Id, Id> orderIdToPricebookId = new Map<Id, Id>();
    for (Order order : orderRecordIdToOrder.values()) {
        orderIdToPricebookId.put(order.Id, order.Pricebook2Id);
    }

    // Create dummy Products
    List<Product2> productsToInsert = new List<Product2>();
    for (Object record : records) {
        Map<String, Object> recordMap = (Map<String, Object>) record;
        Integer itemRecordId = (Integer) recordMap.get('Item_RecordID');
        String itemName = (String) recordMap.get('Item');
        String normalizedItemName = itemName != null ? normalizeProductName(itemName) : null;

        if (itemRecordId != null && !itemRecordIdToProductId.containsKey((Decimal) itemRecordId) && 
            (normalizedItemName != null && !itemNameToProductId.containsKey(normalizedItemName))) {
            productsToInsert.add(new Product2(
                Name = normalizedItemName,
                External_Record_Id__c = (Decimal) itemRecordId,
                IsActive = true,
                Description = 'Created for Sales Order Line sync on ' + Date.today().format()
            ));
        }
    }

    if (!productsToInsert.isEmpty()) {
        try {
            insert productsToInsert;
            for (Product2 product : productsToInsert) {
                itemNameToProductId.put(product.Name, product.Id);
                if (product.External_Record_Id__c != null) {
                    itemRecordIdToProductId.put(product.External_Record_Id__c, product.Id);
                }
            }
        } catch (Exception ex) {
            System.debug('Error inserting Products: ' + ex.getMessage() + ' ' + ex.getStackTraceString());
        }
    }

    // Query existing PricebookEntry records
    Map<Id, Map<Id, Id>> pricebookIdToProductIdToPricebookEntryId = new Map<Id, Map<Id, Id>>();
    Set<Id> allProductIds = new Set<Id>(itemNameToProductId.values());
    allProductIds.addAll(itemRecordIdToProductId.values());
    Set<Id> allPricebookIds = new Set<Id>(orderIdToPricebookId.values());
    if (!allProductIds.isEmpty() && !allPricebookIds.isEmpty()) {
        for (PricebookEntry pbe : [
            SELECT Id, Product2Id, Pricebook2Id, UnitPrice
            FROM PricebookEntry
            WHERE Product2Id IN :allProductIds AND Pricebook2Id IN :allPricebookIds
        ]) {
            if (!pricebookIdToProductIdToPricebookEntryId.containsKey(pbe.Pricebook2Id)) {
                pricebookIdToProductIdToPricebookEntryId.put(pbe.Pricebook2Id, new Map<Id, Id>());
            }
            pricebookIdToProductIdToPricebookEntryId.get(pbe.Pricebook2Id).put(pbe.Product2Id, pbe.Id);
        }
    }

    // Create PricebookEntry records
    List<PricebookEntry> pbesToInsert = new List<PricebookEntry>();
    Map<String, PricebookEntry> pbeKeyToRecord = new Map<String, PricebookEntry>(); // To avoid duplicates
    for (Object record : records) {
        Map<String, Object> recordMap = (Map<String, Object>) record;
        Integer itemRecordId = (Integer) recordMap.get('Item_RecordID');
        String itemName = (String) recordMap.get('Item');
        String normalizedItemName = itemName != null ? normalizeProductName(itemName) : null;
        Id productId = normalizedItemName != null ? itemNameToProductId.get(normalizedItemName) : null;
        if (productId == null && itemRecordId != null) {
            productId = itemRecordIdToProductId.get((Decimal) itemRecordId);
        }
        if (productId != null) {
            Decimal unitPrice = recordMap.get('Rate') != null && (Decimal) recordMap.get('Rate') > 0 ? 
                            (Decimal) recordMap.get('Rate') : 
                            (recordMap.get('TJPrice') != null ? (Decimal) recordMap.get('TJPrice') : 0.0);
            for (Id pricebookId : orderIdToPricebookId.values()) {
                String pbeKey = pricebookId + '-' + productId; // Unique key for Pricebook2Id-Product2Id
                if (!pricebookIdToProductIdToPricebookEntryId.containsKey(pricebookId) || 
                    !pricebookIdToProductIdToPricebookEntryId.get(pricebookId).containsKey(productId)) {
                    if (!pbeKeyToRecord.containsKey(pbeKey)) {
                        PricebookEntry pbe = new PricebookEntry(
                            Pricebook2Id = pricebookId,
                            Product2Id = productId,
                            UnitPrice = unitPrice,
                            IsActive = true
                        );
                        pbesToInsert.add(pbe);
                        pbeKeyToRecord.put(pbeKey, pbe);
                    }
                }
            }
        }
    }

    if (!pbesToInsert.isEmpty()) {
        try {
            insert pbesToInsert;
            for (PricebookEntry pbe : pbesToInsert) {
                if (!pricebookIdToProductIdToPricebookEntryId.containsKey(pbe.Pricebook2Id)) {
                    pricebookIdToProductIdToPricebookEntryId.put(pbe.Pricebook2Id, new Map<Id, Id>());
                }
                pricebookIdToProductIdToPricebookEntryId.get(pbe.Pricebook2Id).put(pbe.Product2Id, pbe.Id);
            }
            System.debug('Inserted ' + pbesToInsert.size() + ' PricebookEntries');
        } catch (DmlException ex) {
            for (Integer i = 0; i < ex.getNumDml(); i++) {
                if (ex.getDmlType(i) == StatusCode.DUPLICATE_VALUE) {
                    System.debug('Duplicate PricebookEntry detected for Pricebook2Id: ' + pbesToInsert[i].Pricebook2Id + 
                                 ', Product2Id: ' + pbesToInsert[i].Product2Id + '. Skipping.');
                } else {
                    System.debug('Error inserting PricebookEntries: ' + ex.getDmlMessage(i) + ' ' + ex.getStackTraceString());
                }
            }
        } catch (Exception ex) {
            System.debug('Unexpected error inserting PricebookEntries: ' + ex.getMessage() + ' ' + ex.getStackTraceString());
        }
    }

    // Re-query PricebookEntry records to ensure all are captured
    if (!allProductIds.isEmpty() && !allPricebookIds.isEmpty()) {
        for (PricebookEntry pbe : [
            SELECT Id, Product2Id, Pricebook2Id, UnitPrice
            FROM PricebookEntry
            WHERE Product2Id IN :allProductIds AND Pricebook2Id IN :allPricebookIds
        ]) {
            if (!pricebookIdToProductIdToPricebookEntryId.containsKey(pbe.Pricebook2Id)) {
                pricebookIdToProductIdToPricebookEntryId.put(pbe.Pricebook2Id, new Map<Id, Id>());
            }
            pricebookIdToProductIdToPricebookEntryId.get(pbe.Pricebook2Id).put(pbe.Product2Id, pbe.Id);
        }
    }

    // Process Sales Order Lines
    try {
        for (Object record : records) {
            Map<String, Object> recordMap = (Map<String, Object>) record;
            Integer extRecordId = (Integer) recordMap.get('RecordID');
            String lineItemNumber = String.valueOf(recordMap.get('Change'));
            String chemicalName = (String) recordMap.get('ChemicalName');
            Integer itemRecordId = (Integer) recordMap.get('Item_RecordID');
            Integer orderRecordId = (Integer) recordMap.get('SalesOrderRecordID');
            String itemName = (String) recordMap.get('Item');
            String normalizedItemName = itemName != null ? normalizeProductName(itemName) : null;

            if (lineItemNumber == null) {
                System.debug('Skipping Sales Order Line record with null Change: ' + recordMap);
                continue;
            }

            OrderItem line;
            if (existingOrderItemMap.containsKey(extRecordId)) {
                line = existingOrderItemMap.get(extRecordId);
                // Ensure OrderId is set for existing OrderItem
                if (line.OrderId == null && orderRecordId != null && orderRecordIdToOrder.containsKey((Decimal) orderRecordId)) {
                    Order order = orderRecordIdToOrder.get((Decimal) orderRecordId);
                    line.OrderId = order.Id;
                }
                // Verify PricebookEntryId for existing OrderItem
                if (line.OrderId != null && line.PricebookEntryId == null) {
                    Order order = orderRecordIdToOrder.get((Decimal) orderRecordId);
                    if (order != null && order.Pricebook2Id != null) {
                        Id pricebookId = order.Pricebook2Id;
                        Id productId = line.Product2Id != null ? line.Product2Id : (normalizedItemName != null ? itemNameToProductId.get(normalizedItemName) : null);
                        if (productId == null && itemRecordId != null) {
                            productId = itemRecordIdToProductId.get((Decimal) itemRecordId);
                        }
                        if (productId != null && pricebookIdToProductIdToPricebookEntryId.containsKey(pricebookId) &&
                            pricebookIdToProductIdToPricebookEntryId.get(pricebookId).containsKey(productId)) {
                            line.PricebookEntryId = pricebookIdToProductIdToPricebookEntryId.get(pricebookId).get(productId);
                        } else {
                            System.debug('No PricebookEntry found for existing OrderItem with ProductId: ' + productId + ' and PricebookId: ' + pricebookId);
                            continue;
                        }
                    } else {
                        System.debug('No valid Order or Pricebook for existing OrderItem with External_Record_Id__c: ' + extRecordId);
                        continue;
                    }
                }
            } else {
                Id productId;
                if (normalizedItemName != null && itemNameToProductId.containsKey(normalizedItemName)) {
                    productId = itemNameToProductId.get(normalizedItemName);
                } else if (itemRecordId != null && itemRecordIdToProductId.containsKey((Decimal) itemRecordId)) {
                    productId = itemRecordIdToProductId.get((Decimal) itemRecordId);
                } else {
                    System.debug('No Product found for Item: ' + itemName + ' or Item_RecordID: ' + itemRecordId);
                    continue;
                }

                line = new OrderItem();
                System.debug('Created new OrderItem for External_Record_Id__c: ' + extRecordId);
                line.Product2Id = productId;

                if (orderRecordId != null && orderRecordIdToOrder.containsKey((Decimal) orderRecordId)) {
                    Order order = orderRecordIdToOrder.get((Decimal) orderRecordId);
                    line.OrderId = order.Id;
                    Id pricebookId = order.Pricebook2Id;
                    if (pricebookId != null && pricebookIdToProductIdToPricebookEntryId.containsKey(pricebookId) &&
                        pricebookIdToProductIdToPricebookEntryId.get(pricebookId).containsKey(productId)) {
                        line.PricebookEntryId = pricebookIdToProductIdToPricebookEntryId.get(pricebookId).get(productId);
                    } else {
                        System.debug('No PricebookEntry found for ProductId: ' + productId + ' and PricebookId: ' + pricebookId + 
                                     '. Product2Ids: ' + pricebookIdToProductIdToPricebookEntryId.get(pricebookId)?.keySet());
                        continue;
                    }
                } else {
                    System.debug('No Order found for SalesOrderRecordID: ' + orderRecordId);
                    continue;
                }

                if (chemicalName != null && chemicalNameToId.containsKey(chemicalName)) {
                    line.Compound__c = chemicalNameToId.get(chemicalName);
                }
            }

            // Map fields
            line.Line_Item_Change__c = String.valueOf(recordMap.get('Change'));
            line.CCL_Number__c = (String) recordMap.get('CCLNumber');
            line.TJ_Price__c = recordMap.get('TJPrice') != null ? (Decimal) recordMap.get('TJPrice') : null;
            line.Quantity = recordMap.get('Quantity') != null ? (Decimal) recordMap.get('Quantity') : null;
            line.UnitPrice = recordMap.get('Rate') != null ? (Decimal) recordMap.get('Rate') : null;
            line.U_M__c = (String) recordMap.get('UnitOfMeasure');
            line.Invoiced__c = recordMap.get('Closed') != null ? (Boolean) recordMap.get('Closed') : false;
            line.External_Record_Id__c = (Decimal) recordMap.get('RecordID');
            line.Description = (String) recordMap.get('POService');

            // Validate required fields before adding to upsert list
            if (line.OrderId == null || line.Product2Id == null || line.PricebookEntryId == null) {
                System.debug('Skipping OrderItem due to missing required fields: OrderId=' + line.OrderId + 
                             ', Product2Id=' + line.Product2Id + ', PricebookEntryId=' + line.PricebookEntryId + 
                             ', External_Record_Id__c=' + line.External_Record_Id__c);
                continue;
            }

            linesToUpsert.add(line);
        }
    } catch (Exception ex) {
        System.debug('Exception occurred in processing records: ' + ex.getMessage() + ' ' + ex.getStackTraceString());
    }

    // Debug OrderItems before upsert
    for (OrderItem line : linesToUpsert) {
        System.debug('OrderItem to upsert: OrderId=' + line.OrderId + ', Product2Id=' + line.Product2Id + 
                     ', PricebookEntryId=' + line.PricebookEntryId + ', External_Record_Id__c=' + line.External_Record_Id__c);
    }

    // Upsert Sales Order Lines
    if (!linesToUpsert.isEmpty()) {
        try {
            upsert linesToUpsert External_Record_Id__c;
            System.debug('Upserted ' + linesToUpsert.size() + ' Sales Order Lines');
        } catch (Exception ex) {
            System.debug('Error upserting Sales Order Lines: ' + ex.getMessage() + ' ' + ex.getStackTraceString());
        }
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
}