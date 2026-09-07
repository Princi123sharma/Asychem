@isTest
private class FetchApiQueueableTest {

    private class MockCalloutWithRecords implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            // Simulate data with one record
            String responseBody = '{"data":[{"Id":"12345","Name":"Test Record"}],"next":null}';
            res.setBody(responseBody);
            return res;
        }
    }

    private class MockCalloutNoRecords implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            // Simulate no data
            String responseBody = '{"data":[], "next":null}';
            res.setBody(responseBody);
            return res;
        }
    }

    @isTest
static void testQueueableConstructorCoverage() {
    Test.setMock(HttpCalloutMock.class, new MockCalloutNoRecords());

    DateTime start = DateTime.now().addDays(-1);
    DateTime enddate = DateTime.now();

    // Run with skip = 100, chainCount = 10
    FetchApiQueueable job = new FetchApiQueueable('Invoice', start, enddate, 100, 10);
    Test.startTest();
    System.enqueueJob(job);
    Test.stopTest();

   
}

    @isTest
    static void testQueueableNoRecords() {
        Test.setMock(HttpCalloutMock.class, new MockCalloutNoRecords());

        DateTime startTime = DateTime.now().addHours(-1);
        DateTime endTime = DateTime.now();
        String tableName = 'SalesOrder';

        Test.startTest();
        System.enqueueJob(new FetchApiQueueable(tableName, startTime, endTime, 0, 1));
        Test.stopTest();

        // After no records, scheduler should kick in
        List<CronTrigger> jobs = [
            SELECT CronJobDetail.Name, CronExpression
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'AutoReschedule_SalesOrder_Min_%'
            AND State = 'WAITING'
        ];
        System.assertEquals(12, jobs.size(), 'Expected 12 scheduled jobs for every 5 mins');
    }

    @isTest
    static void testQueueableAtChainLimit() {
        Test.setMock(HttpCalloutMock.class, new MockCalloutWithRecords());

        DateTime startTime = DateTime.now().addHours(-1);
        DateTime endTime = DateTime.now();
        String tableName = 'SalesOrder';

        Test.startTest();
        System.enqueueJob(new FetchApiQueueable(tableName, startTime, endTime, 0, 1000));
        Test.stopTest();

        // Check that 12 jobs were scheduled
        List<CronTrigger> jobs = [
            SELECT CronJobDetail.Name, CronExpression
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'AutoReschedule_SalesOrder_Min_%'
            AND State = 'WAITING'
        ];
        System.assertEquals(12, jobs.size(), 'Expected 12 recurring jobs to be scheduled');
        for (CronTrigger job : jobs) {
            System.assert(job.CronJobDetail.Name.startsWith('AutoReschedule_SalesOrder_Min_'), 'Scheduled job name mismatch');
        }
    }
}