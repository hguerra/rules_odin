"""Failure-contract tests for odin_collection."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

def _empty_collection_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "rules_odin: odin_collection 'empty_collection' requires at least one .odin file")
    return analysistest.end(env)

empty_collection_test = analysistest.make(
    _empty_collection_test_impl,
    expect_failure = True,
)

def _outside_collection_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "rules_odin: odin_collection 'outside_collection' srcs file")
    return analysistest.end(env)

outside_collection_test = analysistest.make(
    _outside_collection_test_impl,
    expect_failure = True,
)

def _control_character_collection_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "rules_odin: odin_collection 'control_character_collection' collection_root must not contain control characters")
    return analysistest.end(env)

control_character_collection_test = analysistest.make(
    _control_character_collection_test_impl,
    expect_failure = True,
)

def collection_test_suite(name):
    empty_collection_test(
        name = "empty_collection_test",
        target_under_test = ":empty_collection",
    )
    outside_collection_test(
        name = "outside_collection_test",
        target_under_test = ":outside_collection",
    )
    control_character_collection_test(
        name = "control_character_collection_test",
        target_under_test = ":control_character_collection",
    )
    native.test_suite(
        name = name,
        tests = [
            ":empty_collection_test",
            ":outside_collection_test",
            ":control_character_collection_test",
        ],
    )
