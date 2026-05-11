# BlitzPay Monorepo

This context covers the Bazel monorepo that enforces API contract compatibility across all BlitzPay client applications.

## Language

**Contract**:
A Spring Cloud Contract DSL file in `blitz-pay` that defines the expected request/response shape for one API interaction. The authoritative source of truth for what the API guarantees.
_Avoid_: spec, agreement, interface definition

**Stubs JAR**:
A versioned Maven artifact published to GitHub Packages by the `blitz-pay` CI. Contains WireMock-compatible JSON stubs generated from the Contracts. Consumers download this to run contract tests without hitting the real API.
_Avoid_: mock JAR, fake server, test doubles

**Consumer Contract Test**:
A test in a client repo (Angular dashboard or React Native app) that starts WireMock seeded with the Stubs JAR and runs HTTP calls against it. Fails if the client code is incompatible with the published Contract.
_Avoid_: integration test, mock test, API test

**Contract Enforcement**:
The Bazel build graph in this monorepo that declares each client's Consumer Contract Tests as a dependency on the Stubs JAR. A change to a Contract that breaks a client surfaces as a failing `bazel test` in CI before any deployment.
_Avoid_: contract validation, API check

## Components

**blitz-pay** (`github.com/elegant-software/blitz-pay`):
Kotlin/Spring Boot backend. The Contract producer. Publishes the Stubs JAR to GitHub Packages on every CI run that changes a Contract.

**blitz-pay-prototype** (`github.com/elegant-software/blitz-pay-react-native`):
Two React Native (Expo) mobile apps — consumer-facing (`blitz-pay`) and merchant-facing (`blitz-pay-merchant`). Both are Contract consumers.

**blitzpay-admin-dashboard** (`github.com/elegant-software/blitzpay-admin-dashboard`):
Angular web app for merchant management. Contract consumer.

## Relationships

- **blitz-pay** produces Contracts → generates Stubs JAR → publishes to GitHub Packages
- **blitzpay-admin-dashboard** declares a Consumer Contract Test → depends on Stubs JAR
- **blitz-pay-prototype/blitz-pay** declares a Consumer Contract Test → depends on Stubs JAR
- **blitz-pay-prototype/blitz-pay-merchant** declares a Consumer Contract Test → depends on Stubs JAR
- The monorepo holds all three as git submodules — original repos remain unchanged on GitHub

## CI Trigger Chain

```
blitz-pay CI (Gradle)
  → runs contractTest
  → publishes Stubs JAR to GitHub Packages
  → dispatches blitzpay-mono-repo CI via workflow_dispatch

blitzpay-mono-repo CI (Bazel)
  → bazel test //blitzpay-admin-dashboard:contract_tests
  → bazel test //blitz-pay-prototype/blitz-pay:contract_tests
  → bazel test //blitz-pay-prototype/blitz-pay-merchant:contract_tests
```

## Architecture decisions

- Bazel scope is contract enforcement only — each repo builds itself with its own tool (Gradle, npm, Expo)
- Stubs JAR is published to GitHub Packages (not Nexus or Artifactory)
- Repos are embedded as git submodules — original GitHub repos remain authoritative
- React Native/Expo build is intentionally excluded from Bazel (Metro bundler incompatibility)
