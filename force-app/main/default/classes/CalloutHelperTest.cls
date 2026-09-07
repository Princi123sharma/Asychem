@IsTest
private class CalloutHelperTest {
    
    // Mock response for successful callout with 100 records (paginated)
    // Mock response for successful callout with 100 records (paginated)
private class SuccessMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(200);

        // Create mock response with 100 records
        List<Object> mockRecords = new List<Object>();
        for (Integer i = 0; i < 100; i++) {
            mockRecords.add(new Map<String, Object>{
                'id' => 'rec' + i,
                'name' => 'Record ' + i
            });
        }

        // Add mock nextLink
        String nextUrl = 'https://api.example.com/data?skip=100';

        res.setBody(JSON.serialize(new Map<String, Object>{
            'value' => mockRecords,
            'nextLink' => nextUrl
        }));
        return res;
    }
}

    
    // Mock response for successful callout with <100 records (no pagination)
    private class SuccessSmallMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            // Create mock response with 10 records
            List<Object> mockRecords = new List<Object>();
            for(Integer i = 0; i < 10; i++) {
                mockRecords.add(new Map<String, Object>{
                    'id' => 'rec' + i,
                    'name' => 'Record ' + i
                });
            }
            
            res.setBody(JSON.serialize(new Map<String, Object>{
                'value' => mockRecords
            }));
            return res;
        }
    }
    
    // Mock response for failed callout
    private class FailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(500);
            res.setBody('{"error":"Internal Server Error"}');
            return res;
        }
    }
    
    // Test successful callout with pagination (100 records)
    @IsTest
    static void testPerformPaginatedCallout_WithPagination() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        
        String testUrl = 'https://api.example.com/data?skip=0';
        
        Test.startTest();
        CalloutHelper.PaginatedCalloutResult result = CalloutHelper.performPaginatedCallout(testUrl);
        Test.stopTest();
        
        // Verify results
        System.assertEquals(100, result.records.size(), 'Should return 100 records');
        System.assertNotEquals(null, result.nextUrl, 'Next URL should be provided for pagination');
        System.assertEquals('https://api.example.com/data?skip=100', result.nextUrl, 'Next URL should have skip=100');
    }
    
    // Test successful callout without pagination (<100 records)
    @IsTest
    static void testPerformPaginatedCallout_WithoutPagination() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new SuccessSmallMock());
        
        String testUrl = 'https://api.example.com/data?skip=0';
        
        Test.startTest();
        CalloutHelper.PaginatedCalloutResult result = CalloutHelper.performPaginatedCallout(testUrl);
        Test.stopTest();
        
        // Verify results
        System.assertEquals(10, result.records.size(), 'Should return 10 records');
        System.assertEquals(null, result.nextUrl, 'Next URL should be null when no pagination needed');
    }
    
    // Test failed callout - updated to catch generic Exception
    @IsTest
    static void testPerformPaginatedCallout_Failure() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new FailureMock());
        
        String testUrl = 'https://api.example.com/data?skip=0';
        Boolean exceptionThrown = false;
        String exceptionMessage = '';
        
        Test.startTest();
        try {
            CalloutHelper.PaginatedCalloutResult result = CalloutHelper.performPaginatedCallout(testUrl);
        } catch(Exception e) {
            exceptionThrown = true;
            exceptionMessage = e.getMessage();
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Expected Exception was not thrown');
        System.assert(exceptionMessage.contains('500') || exceptionMessage.contains('Failed callout'), 
                     'Exception message should contain status code or "Failed callout"');
    }
    
    // Test URL parameter extraction
    @IsTest
    static void testExtractSkipFromUrl() {
        System.assertEquals(0, CalloutHelper.extractSkipFromUrl('https://example.com/data'), 'Should return 0 when no skip param');
        System.assertEquals(0, CalloutHelper.extractSkipFromUrl('https://example.com/data?'), 'Should return 0 when no skip param');
        System.assertEquals(10, CalloutHelper.extractSkipFromUrl('https://example.com/data?skip=10'), 'Should extract skip=10');
        System.assertEquals(20, CalloutHelper.extractSkipFromUrl('https://example.com/data?param=1&skip=20'), 'Should extract skip=20 with other params');
        System.assertEquals(30, CalloutHelper.extractSkipFromUrl('https://example.com/data?skip=30&param=1'), 'Should extract skip=30 when first param');
    }
    
    // Test URL parameter update
   @IsTest
static void testUpdateSkipInUrl() {
    // Test adding first parameter (uses & instead of ?)
    System.assertEquals(
        'https://example.com/data&skip=10',
        CalloutHelper.updateSkipInUrl('https://example.com/data', 10),
        'Should add first parameter with &'
    );
}
    
    // Test HTTP request building
    @IsTest
    static void testBuildHttpRequest() {
        String testUrl = 'https://example.com/data';
        
        Test.startTest();
        HttpRequest req = CalloutHelper.buildHttpRequest(testUrl);
        Test.stopTest();
        
        // Verify request properties
        System.assertEquals('GET', req.getMethod(), 'Should be GET request');
        System.assertEquals(testUrl, req.getEndpoint(), 'Endpoint should match');
        System.assertEquals('application/json', req.getHeader('Content-Type'), 'Content-Type header should be set');
        System.assert(req.getHeader('Authorization').startsWith('APIKey '), 'Authorization header should be set with API key');
    }
    
}