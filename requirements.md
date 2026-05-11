# Contract Enforcement — Implementation Requirements

These three tasks wire up API contract enforcement across the BlitzPay platform.
The monorepo Bazel infrastructure is already in place. Each task below is independent
and can be done in parallel, **except** that the Bazel contract tests cannot be run
in CI until Task 1 is done (the stubs JAR must be published first).

---

## Task 1 — blitz-pay: Publish stubs JAR to GitHub Packages

**Repo:** `github.com/elegant-software/blitz-pay`

### Background
``
Spring Cloud Contract already generates a stubs JAR via the `verifierStubsJar` Gradle
task. That JAR contains WireMock-compatible JSON stubs derived from the contract DSL
files in `src/contractTest/resources/contracts/`. It is not published anywhere yet.
This task publishes it to GitHub Packages so the frontend and mobile consumer tests
can download it.

### Changes required

**1. `build.gradle.kts` — add the `maven-publish` plugin and publishing block**

Add `maven-publish` to the existing `plugins {}` block:

```kotlin
plugins {
    // ... existing plugins ...
    `maven-publish`
}
```

Add the following block anywhere after the existing `tasks` configuration:

```kotlin
publishing {
    publications {
        create<MavenPublication>("stubs") {
            artifact(tasks.named("verifierStubsJar"))
            groupId = "com.elegant.software.blitzpay"
            artifactId = "blitz-pay"
            version = project.version.toString()
        }
    }
    repositories {
        maven {
            name = "GitHubPackages"
            url = uri("https://maven.pkg.github.com/elegant-software/blitz-pay")
            credentials {
                username = providers.gradleProperty("githubActor").orNull
                    ?: System.getenv("GITHUB_ACTOR")
                password = providers.gradleProperty("githubToken").orNull
                    ?: System.getenv("GITHUB_TOKEN")
            }
        }
    }
}
```

**2. Commit the new GitHub Actions workflow**

The file `.github/workflows/publish-stubs.yml` already exists in your working tree
(it was added via the monorepo setup). Commit and push it to the `blitz-pay` repo.
It triggers on any push to `main` or `develop` that changes a contract file and:
- Runs `verifierStubsJar`
- Publishes the stubs JAR to GitHub Packages
- Dispatches the monorepo contract-test CI

**3. Create a GitHub secret on the blitz-pay repo**

Name: `MONO_REPO_DISPATCH_TOKEN`
Value: A GitHub Personal Access Token with the `workflow` scope granted on
`github.com/elegant-software/blitzpay-mono-repo`.

This token is used by the workflow to trigger the monorepo CI after stubs are published.

### How to verify

Run locally:
```bash
./gradlew verifierStubsJar
```
Confirm the file `build/libs/blitz-pay-<version>-stubs.jar` is created.
Then push a change to any file under `src/contractTest/resources/contracts/` on `main`
and confirm the `Publish Contract Stubs` workflow succeeds in GitHub Actions.

---

## Task 2 — blitzpay-admin-dashboard: Angular consumer contract test

**Repo:** `github.com/elegant-software/blitzpay-admin-dashboard`

### Background

The dashboard already has a `MerchantApiService` that makes HTTP calls to the
blitz-pay backend. The existing `merchant-api.service.spec.ts` uses Angular's
`HttpTestingController` — a pure in-memory mock that never touches a real server.
A contract test must use the real `HttpClient` pointing at a WireMock server seeded
with the stubs JAR from Task 1. The Bazel runner sets the environment variable
`CONTRACT_TEST_BASE_URL` before the tests run.

### Changes required

**1. `package.json` — add the contract test script**

```json
"scripts": {
  "start": "ng serve",
  "build": "ng build",
  "test": "ng test",
  "test:contract": "ng test --include=**/*.contract.spec.ts --browsers=ChromeHeadless --watch=false"
}
```

**2. Create `src/app/services/merchant-api.contract.spec.ts`**

```typescript
import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { MerchantApiService } from './merchant-api.service';
import { BackendEnvironment } from '../models/merchant-catalog.models';

const contractBaseUrl = process.env['CONTRACT_TEST_BASE_URL'] ?? 'http://localhost:8089';

const environment: BackendEnvironment = {
  key: 'contract',
  label: 'Contract',
  baseUrl: contractBaseUrl,
};

describe('MerchantApiService — contract tests', () => {
  let service: MerchantApiService;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [MerchantApiService, provideHttpClient()],
    });
    service = TestBed.inject(MerchantApiService);
  });

  it('POST /v1/payments/request returns paymentRequestId', (done) => {
    // Add one it() block per contract file in blitz-pay/src/contractTest/resources/contracts/.
    // Start with the payment request contract that already exists.
    // Each test calls the real service method and asserts the response shape.
    done(); // replace with real assertion once Task 1 stubs are available
  });
});
```

Add a real `it()` block for each contract file that exists in
`blitz-pay/src/contractTest/resources/contracts/`. The first one is
`should_create_payment_request.groovy` — the endpoint is `POST /v1/payments/request`.

### How to verify
``
With WireMock running locally on port 8089 and seeded with the stubs JAR:
```bash
CONTRACT_TEST_BASE_URL=http://localhost:8089 npm run test:contract
```
The test should pass. With WireMock not running, it should fail with a connection error
(which confirms it is hitting a real server, not a mock).

---

## Task 3 — blitz-pay-prototype: React Native consumer contract tests

**Repo:** `github.com/elegant-software/blitz-pay-react-native`

This task applies to **both** apps in the repo:
- `blitz-pay/` — consumer-facing mobile app
- `blitz-pay-merchant/` — merchant-facing mobile app

### Background

Neither app has Jest configured for contract testing. The consumer app has a test
runner script but no Jest. The merchant app has no test suite at all. Both apps
make HTTP calls to blitz-pay via `fetch` using a base URL from `config.apiUrl`.
The Bazel runner sets `CONTRACT_TEST_BASE_URL` before tests run.

### Changes required — apply to both `blitz-pay/` and `blitz-pay-merchant/`

**1. Install Jest**

```bash
npm install --save-dev jest @types/jest babel-jest
```

**2. `package.json` — add the contract test script**

```json
"scripts": {
  "test:contract": "jest --testPathPattern=__contract__"
}
```

Also add a Jest config entry to `package.json`:

```json
"jest": {
  "preset": "babel-jest",
  "testEnvironment": "node",
  "testMatch": ["**/__contract__/**/*.test.ts"]
}
```

**3. Create `src/__contract__/payments.contract.test.ts`**

```typescript
const baseUrl = process.env.CONTRACT_TEST_BASE_URL ?? 'http://localhost:8090';

describe('blitz-pay contract tests', () => {
  it('POST /v1/payments/request returns 202 with paymentRequestId', async () => {
    const response = await fetch(`${baseUrl}/v1/payments/request`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        paymentRequestId: null,
        orderId: 'ORDER-123',
        amountMinorUnits: 1099,
        currency: 'EUR',
        userDisplayName: 'Jane Doe',
        userEmail: 'jane.doe@example.com',
        redirectReturnUri: 'https://merchant.example.com/return',
      }),
    });

    expect(response.status).toBe(202);
    const body = await response.json();
    expect(body.paymentRequestId).toMatch(
      /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/
    );
  });

  // Add one test per contract file in blitz-pay/src/contractTest/resources/contracts/.
});
```

> Note: The request body and response assertions must exactly match the contract DSL
> in `blitz-pay/src/contractTest/resources/contracts/payments/should_create_payment_request.groovy`.
> When new contracts are added to blitz-pay, add a matching test here.

### How to verify

```bash
CONTRACT_TEST_BASE_URL=http://localhost:8090 npm run test:contract
```
Run from inside `blitz-pay/` and separately from inside `blitz-pay-merchant/`.
Tests should pass with WireMock running and seeded, fail without it.

---

## Order of execution

```
Task 1  →  Tasks 2 and 3 can be written in parallel with Task 1,
           but Bazel CI cannot run until Task 1 stubs are published.
```

Once all three tasks are merged, the full enforcement chain is:

```
Push contract change to blitz-pay
  → publish-stubs.yml publishes stubs JAR to GitHub Packages
  → dispatches blitzpay-mono-repo contract-tests.yml
  → bazel test //:contract_tests
      → admin dashboard contract test (Task 2)
      → mobile consumer contract test (Task 3)
      → mobile merchant contract test (Task 3)
```
