public class CalloutHelper {

    public class PaginatedCalloutResult {
        public List<Object> records;
        public String nextUrl;

        public PaginatedCalloutResult(List<Object> records, String nextUrl) {
            this.records = records;
            this.nextUrl = nextUrl;
        }
    }

      private static final String API_KEY = 'NjdmNjBiNGMxODQwNmI5YTI3NTdlOWY5LjkyQzA2QUY0QzlEMzQxQ0E4QzRGOEE5REZBNDNEQjk2';

     public static PaginatedCalloutResult performPaginatedCallout(String url) {
    Http http = new Http();
    HttpRequest req = buildHttpRequest(url);
    HttpResponse res = http.send(req);

    if (res.getStatusCode() == 200) {
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> records = (List<Object>) responseMap.get('value');
        String nextLink = (String) responseMap.get('nextLink');

        return new PaginatedCalloutResult(records, nextLink);
    } else {
        System.debug('Error fetching data: ' + res.getBody());
        logger.error(res.getBody());
        Logger.saveLog();
        throw new CalloutException('Failed callout: ' + res.getStatusCode());
    }
}

        @TestVisible
    	private static HttpRequest buildHttpRequest(String url) {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(url);
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'APIKey ' + API_KEY);
            return req;
        }

        @TestVisible
        private static Integer extractSkipFromUrl(String url) {
        Pattern skipPattern = Pattern.compile('[&?]skip=(\\d+)');
        Matcher matcher = skipPattern.matcher(url);
        if (matcher.find()) {
            return Integer.valueOf(matcher.group(1));
        }
        return 0;
    }
    
    @TestVisible
     private static String updateSkipInUrl(String url, Integer newSkip) {
        if (url.contains('skip=')) {
            return url.replaceAll('skip=\\d+', 'skip=' + newSkip);
        }
        return url + '&skip=' + newSkip;
    }
}