/**
 * @description Batch Apex class to fetch a large volume of records from a paginated external API.
 * It uses the "Gather, then Process" pattern within each execute chunk to safely perform
 * both callouts and DML operations without violating Salesforce governor limits.
 */
public class FetchApiBatch implements Database.Batchable<Integer>, Database.AllowsCallouts, Database.Stateful {

    // --- Member Variables ---
    private final String tableName;
    private final DateTime startTime;
    private final DateTime endTime;
    private final Integer PAGE_SIZE = 100;
    private Boolean stopFurtherApiCalls = false;
    private integer apiCounter = 0;
    

    private final Integer TOTAL_RECORDS = 50000;  

    /**
     * @description Constructor to initialize the batch job with necessary parameters.
     * @param tableName The name of the API table to query (e.g., 'Invoice', 'SalesOrder').
     * @param startTime The start of the date range filter.
     * @param endTime The end of the date range filter.
     */
    public FetchApiBatch(String tableName, DateTime startTime, DateTime endTime) {
        this.tableName = tableName;
        this.startTime = startTime;
        this.endTime = endTime;
    }

    /**
     * @description The start method creates the "work" for the batch job.
     * It generates a list of 'skip' values, where each value represents a page to be fetched.
     */
    public Iterable<Integer> start(Database.BatchableContext bc) {

        System.debug('Batch Start for table: ' + tableName);
        List<Integer> skipValues = new List<Integer>();
        
         Integer maxRecords = Test.isRunningTest() ? PAGE_SIZE : TOTAL_RECORDS;
        
        for (Integer i = 0; i < maxRecords; i += PAGE_SIZE) {
            skipValues.add(i);
        }
        
        System.debug('Total pages to process: ' + skipValues.size());
        return skipValues;
    }


    /**
     * @description The execute method processes one chunk of pages. It gathers all records
     * from the pages in its scope first, then performs a single DML operation.
     */
    public void execute(Database.BatchableContext bc, List<Integer> scope) {
    System.debug('Total API hit--' + apiCounter);
    if (stopFurtherApiCalls) {
        System.debug('🚫 Skipping this chunk because stopFurtherApiCalls = true');
        return;
    }

    List<Object> allRecordsInThisChunk = new List<Object>();
    String filter = 'LastModifiedDate ge \'' + startTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss') +
                    '\' and LastModifiedDate lt \'' + endTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss') + '\'';
    String encodedFilter = EncodingUtil.urlEncode(filter, 'UTF-8');

    for (Integer skipValue : scope) {
        if (stopFurtherApiCalls) break;

        try {
            String url = 'https://rest.method.me/api/v1/tables/' + tableName +
                         '?skip=' + skipValue +
                         '&top=' + PAGE_SIZE +
                         '&filter=' + encodedFilter;

            CalloutHelper.PaginatedCalloutResult result = CalloutHelper.performPaginatedCallout(url);

            if (result.records != null && !result.records.isEmpty()) {
                allRecordsInThisChunk.addAll(result.records);
            }
            apiCounter++;
            // 🚨 If no more records indicated by nextLink
            if (String.isBlank(result.nextUrl)) {
                stopFurtherApiCalls = true;
                System.debug('🔕 nextLink is blank — setting stopFurtherApiCalls = true');
            }

        } catch (Exception e) {
            logger.error(e.getMessage());
            Logger.saveLog();
        }
    }

    if (!allRecordsInThisChunk.isEmpty()) {
        try {
            TriggerControlHelper.isBatchRunning = true;
            MethodSyncController.processData(allRecordsInThisChunk, tableName);
        } catch (DmlException e) {
            logger.error(e.getMessage());
            Logger.saveLog();
        }
    }
}


    /**
     * @description The finish method runs once after all chunks have been processed.
     * Ideal for sending a summary notification.
     */

public void finish(Database.BatchableContext bc) {
    System.debug('Batch completed for table: ' + tableName);

    String jobName00 = 'AutoReschedule_' + tableName + '_00';
    String jobName30 = 'AutoReschedule_' + tableName + '_30';

    // Fetch all scheduled jobs for this table
    List<CronTrigger> existingJobs = [
        SELECT CronJobDetail.Name, NextFireTime
        FROM CronTrigger
        WHERE CronJobDetail.Name IN :new List<String>{ jobName00, jobName30 }
        AND State = 'WAITING'
    ];

    // Extract existing job names
    Set<String> existingJobNames = new Set<String>();
    for (CronTrigger ct : existingJobs) {
        existingJobNames.add(ct.CronJobDetail.Name);
    }

    // Schedule hh:00 job if not present
    if (!existingJobNames.contains(jobName00)) {
        System.schedule(jobName00, '0 0 * * * ?', new FetchApiBatchScheduler(tableName));
        System.debug('Scheduled job at hh:00 for ' + tableName);
    }

    // Schedule hh:30 job if not present
    if (!existingJobNames.contains(jobName30)) {
        System.schedule(jobName30, '0 30 * * * ?', new FetchApiBatchScheduler(tableName));
        System.debug('Scheduled job at hh:30 for ' + tableName);
    }

    System.debug('✅ Recurring jobs ensured for table: ' + tableName);
}


}