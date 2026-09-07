public class FetchApiQueueable implements Queueable, Database.AllowsCallouts {

    private final String tableName;
    private final DateTime startTime;
    private final DateTime endTime;
    private final Integer skip;
    private final Integer chainCount;

    private static final Integer PAGE_SIZE = 100;
    private static final Integer SAFE_CHAIN_LIMIT = 1000;

    public FetchApiQueueable(String tableName, DateTime startTime, DateTime endTime, Integer skip, Integer chainCount) {
        this.tableName = tableName;
        this.startTime = startTime;
        this.endTime = endTime;
        this.skip = skip;
        this.chainCount = chainCount;
    }

    public void execute(QueueableContext context) {
        try {
            String baseUrl = 'https://rest.method.me/api/v1/tables/' + tableName.toLowerCase();
			String filterCriteria = 'LastModifiedDate ge \'' + startTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss') + 
                      '\' and LastModifiedDate lt \'' + endTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss') + '\'';

			String urlToCall = baseUrl +'?top=' + PAGE_SIZE +'&skip=' + skip +'&filter=' + EncodingUtil.urlEncode(filterCriteria, 'UTF-8');

            CalloutHelper.PaginatedCalloutResult result = CalloutHelper.performPaginatedCallout(urlToCall);

            System.debug('🔁 Fetching page with skip=' + skip + ', chain=' + chainCount);
			System.debug('result.records--' + result.records);
            if (result.records != null && !result.records.isEmpty()) {
                TriggerControlHelper.isBatchRunning = true;
                MethodSyncController.processData(result.records, tableName);

                // Chain next job if still under safe limit
                if (chainCount < SAFE_CHAIN_LIMIT) {
                    System.enqueueJob(new FetchApiQueueable(
                        tableName, startTime, endTime, skip + PAGE_SIZE, chainCount + 1
                    ));
                } else {
                    System.debug('🛑 Reached SAFE_CHAIN_LIMIT of ' + SAFE_CHAIN_LIMIT);
                    ensureRecurringSchedule();
                }

            } else {
                System.debug('✅ No more records returned at skip=' + skip);
                ensureRecurringSchedule();
            }

        } catch (Exception e) {
            System.debug('❌ Error in queueable fetch: ' + e.getMessage());
        }
    }

    private void ensureRecurringSchedule() {
    List<String> minuteOffsets = new List<String>{
        '00', '05', '10', '15', '20', '25', '30', '35', '40', '45', '50', '55'
    };

    for (String minute : minuteOffsets) {
        String jobName = 'AutoReschedule_' + tableName + '_Min_' + minute;

        // Check if job already scheduled
        List<CronTrigger> existingJobs = [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name = :jobName AND State = 'WAITING'
        ];

        if (existingJobs.isEmpty()) {
            String cronExpr = '0 ' + minute + ' * * * ?'; // second, minute, hour, day, month, day-of-week
            System.schedule(jobName, cronExpr, new FetchApiBatchScheduler(tableName));
            System.debug('✅ Scheduled: ' + jobName + ' with cron: ' + cronExpr);
        } else {
            System.debug('ℹ️ Job already exists: ' + jobName);
        }
    }
}
}