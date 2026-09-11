global class SharePointDeletionSyncScheduler implements Schedulable {
    global void execute(SchedulableContext context) {
        System.enqueueJob(new SharePointDeletionSync());
    }
}