"""Macro for running consumer contract tests against WireMock stubs."""

def consumer_contract_test(name, stubs_jar, test_cmd, wiremock_port = "8089", **kwargs):
    """Runs a consumer contract test suite against WireMock seeded with stubs_jar.

    Args:
        name:         Bazel target name
        stubs_jar:    Label of the stubs JAR file (downloaded from GitHub Packages)
        test_cmd:     Shell command to run the consumer tests (list of strings)
        wiremock_port: Port WireMock will listen on (default 8089)
    """
    native.sh_test(
        name = name,
        srcs = ["//tools/contract_test:wiremock_runner.sh"],
        args = [
            "$(location @maven//:org_wiremock_wiremock_standalone)",
            "$(location %s)" % stubs_jar,
            wiremock_port,
        ] + test_cmd,
        data = [
            "@maven//:org_wiremock_wiremock_standalone",
            stubs_jar,
        ],
        **kwargs
    )
