/**
* @File Name : FetchApiBatchScheduler.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : July 23, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | July 23, 2025 |   | Initial Version
**/

public class FetchApiBatchScheduler implements Schedulable {
    @TestVisible private String tableName;

    public FetchApiBatchScheduler(String tableName) {
        this.tableName = tableName;
    }

    public void execute(SchedulableContext sc) {
        // Set time window: now to now - 2 hours
        DateTime endTime = DateTime.now();
        DateTime startTime = endTime.addHours(-2);

        System.enqueueJob(
            new FetchApiQueueable(tableName, startTime, endTime, 0, 1)
        );
    }
}