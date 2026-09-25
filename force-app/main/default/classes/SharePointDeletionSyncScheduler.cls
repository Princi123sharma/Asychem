public class SharePointDeletionSyncScheduler implements Schedulable {
    public void execute(SchedulableContext context) {
        System.enqueueJob(new SharePointDeletionSync());
    }
}
