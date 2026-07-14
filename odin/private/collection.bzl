"""Implementation of the odin_collection rule."""

load("//odin/private:common.bzl", "OdinLibraryInfo")

def _fail_path(target_name, message):
    fail("rules_odin: odin_collection '{}' collection_root {}".format(
        target_name,
        message,
    ))

def _validate_collection_root(path, target_name):
    if not path:
        _fail_path(target_name, "must not be empty")
    for control in ["\n", "\r", "\t"]:
        if control in path:
            _fail_path(target_name, "must not contain control characters")
    if path.startswith("/") or "\\" in path or "//" in path:
        _fail_path(target_name, "must be a normalized relative path")
    for part in path.split("/"):
        if part in ["", ".", ".."]:
            _fail_path(target_name, "must not contain '.', '..', or empty segments")

def _odin_collection_impl(ctx):
    srcs = ctx.files.srcs
    if not srcs:
        fail("rules_odin: odin_collection '{}' requires at least one .odin file in srcs".format(
            ctx.label.name,
        ))

    _validate_collection_root(ctx.attr.collection_root, ctx.label.name)

    root_parts = [
        ctx.label.workspace_root,
        ctx.label.package,
        ctx.attr.collection_root,
    ]
    collection_root = "/".join([part for part in root_parts if part])
    root_prefix = collection_root + "/"
    for src in srcs:
        if not src.path.startswith(root_prefix):
            fail(
                "rules_odin: odin_collection '{}' srcs file '{}' is outside collection_root '{}'".format(
                    ctx.label.name,
                    src.short_path,
                    ctx.attr.collection_root,
                ),
            )

    transitive_srcs = depset(srcs)
    info = OdinLibraryInfo(
        srcs = transitive_srcs,
        collection_name = ctx.label.name,
        collection_root = collection_root,
        pkg_dir = collection_root,
        transitive_srcs = transitive_srcs,
        transitive_collections = [(
            ctx.label.name,
            collection_root,
            str(ctx.label),
        )],
    )

    return [
        DefaultInfo(
            files = transitive_srcs,
            runfiles = ctx.runfiles(files = srcs),
        ),
        info,
    ]

odin_collection = rule(
    implementation = _odin_collection_impl,
    doc = "Aggregates a nested Odin collection without compiling it separately.",
    attrs = {
        "collection_root": attr.string(
            doc = "Normalized path containing the collection packages, relative to this Bazel package.",
            mandatory = True,
        ),
        "srcs": attr.label_list(
            doc = "All .odin files nested below collection_root.",
            allow_files = [".odin"],
            mandatory = True,
        ),
    },
)
