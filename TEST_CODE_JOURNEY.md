# Apex Test and Deployment Readiness Journey

## Purpose

This document records the Apex test verification performed before a Salesforce production deployment. It is a release record, not a place for credentials, access tokens, or production configuration values.

## Test execution

The full local Apex test suite was run against the configured Salesforce org:

```powershell
sf apex run test --test-level RunLocalTests --code-coverage --wait 30
```

The CLI displayed an `AbortError` after 30 minutes. In this case, the error meant the CLI wait period expired; it did not establish that the test run failed or was cancelled in Salesforce. The asynchronous test run was then retrieved using its Test Run ID.

## Results

| Measure | Result |
| --- | ---: |
| Test run ID | `707cf00001GHFMY` |
| Tests run | 1,301 |
| Pass rate | 100% |
| Failed tests | 0 |
| Skipped tests | 0 |
| Test execution time | 191,223 ms (about 3.2 minutes) |
| Org-wide Apex coverage | 87% |
| This test run's coverage | 88% |
| Covered lines | 7,931 of 9,042 |

The org-wide coverage is above Salesforce's minimum production-deployment requirement of 75% aggregate Apex coverage. The final coverage calculation is still made during the actual production validation/deployment.

## Retrieve a completed test run

Use the Test Run ID returned by Salesforce rather than rerunning all tests merely to see the result:

```powershell
sf apex get test --test-run-id <TEST_RUN_ID>
```

Retrieve the coverage summary:

```powershell
sf apex get test --test-run-id <TEST_RUN_ID> --code-coverage
```

Retrieve detailed coverage per test method when investigating uncovered code:

```powershell
sf apex get test --test-run-id <TEST_RUN_ID> --code-coverage --detailed-coverage
```

For an archivable machine-readable report:

```powershell
sf apex get test --test-run-id <TEST_RUN_ID> --code-coverage --result-format json
```

## Production readiness checks

Before the production release:

1. Run a validation deployment to production with `RunLocalTests`; review every deployment error, warning, and the final coverage result.
2. Confirm no Apex trigger has zero coverage.
3. Test the release in a full or production-like sandbox with the intended permissions and integrations.
4. Verify SharePoint production setup: `SharePoint_Graph` Named Credential, external-credential principal assignment, Microsoft Entra consent/Graph permissions, and the `Default` `SharePoint_Config__mdt` record with production drive and folder IDs.
5. Do not commit secrets, tokens, or production IDs to source control.
6. Test SharePoint folder creation, a normal file upload, unsupported file types, files greater than 4 MB, deletion synchronization, and files linked to more than one Salesforce record.
7. Run SharePoint backfill in a sandbox first; inspect resulting folder IDs before performing a controlled production backfill.
8. Schedule and monitor the deletion synchronization job after deployment. Review existing batch and scheduled jobs to avoid duplicates or platform-limit issues.

## Known integration constraints

- Trigger-driven SharePoint uploads support simple Graph uploads up to 4 MB. Larger Salesforce Files need the streaming-worker or direct-browser-upload design.
- The project documents both `Contracts` and `Legal Contracts` terminology. Confirm the intended production SharePoint folder name before sign-off.
- Passing Apex tests verify application logic; they do not prove that production credentials, Microsoft Graph permissions, external systems, or scheduled jobs are configured correctly.
