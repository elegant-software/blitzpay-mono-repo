"""Macro for running consumer contract tests against WireMock stubs."""

load("@rules_jvm_external//:defs.bzl", "artifact")

def consumer_contract_test(name, stubs_jar, test_cmd, app_files, wiremock_port = "8089", **kwargs):
    """Runs a consumer contract test suite against WireMock seeded with stubs_jar.

    Args:
        name:         Bazel target name
        stubs_jar:    Label of the stubs JAR file (downloaded from GitHub Packages)
        test_cmd:     Shell command to run the consumer tests (list of strings)
        app_files:    Label containing the consumer app files needed at runtime
        wiremock_port: Port WireMock will listen on (default 8089)
    """
    native.sh_test(
        name = name,
        srcs = ["//tools/contract_test:wiremock_runner.sh"],
        args = [
            "$(location %s)" % artifact("org.wiremock:wiremock-standalone"),
            "$(location %s)" % artifact(stubs_jar),
            wiremock_port,
        ] + test_cmd,
        data = [
            artifact("org.wiremock:wiremock-standalone"),
            artifact(stubs_jar),
            app_files,
        ],
        **kwargs
    )
