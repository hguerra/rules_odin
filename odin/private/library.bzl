"""Implementation of the odin_library rule.

An odin_library groups Odin source files in a directory and exposes them
via OdinLibraryInfo so that odin_binary targets can import them as collections.

The collection name is the label name of the odin_library target.
The collection root is the parent directory of the package directory,
so that `import "<name>:<pkg_dir_basename>"` resolves correctly.
"""

load("//odin/private:common.bzl", "OdinLibraryInfo", "get_package_dir", "normalize_collections")

def _odin_library_impl(ctx):
    srcs = ctx.files.srcs
    pkg_dir = get_package_dir(srcs, "odin_library")

    # Reject root-level srcs: the collection root is the parent of the
    # package directory. If srcs are at the workspace root, there is no
    # parent directory to serve as the collection root.
    if not pkg_dir:
        fail(
            "odin_library '{}' srcs must be in a subdirectory ".format(ctx.label.name) +
            "(the collection root is derived from the parent directory of the package). " +
            "Files at the workspace root have no parent directory.",
        )

    # The collection root is the parent of the package directory.
    # E.g., if pkg_dir is "e2e/smoke/lib", collection_root is "e2e/smoke".
    # If pkg_dir is "lib" (top-level dir), collection_root is ".".
    # The import in Odin would be: import "<name>:lib"
    parts = pkg_dir.rsplit("/", 1)
    if len(parts) < 2:
        collection_root = "."
    else:
        collection_root = parts[0]

    transitive_srcs = [dep[OdinLibraryInfo].transitive_srcs for dep in ctx.attr.deps]
    collections = [(
        ctx.label.name,
        collection_root,
        str(ctx.label),
    )]
    for dep in ctx.attr.deps:
        collections.extend(dep[OdinLibraryInfo].transitive_collections)

    info = OdinLibraryInfo(
        srcs = depset(srcs),
        collection_name = ctx.label.name,
        collection_root = collection_root,
        pkg_dir = pkg_dir,
        transitive_srcs = depset(
            direct = srcs,
            transitive = transitive_srcs,
        ),
        transitive_collections = normalize_collections(
            collections,
            "odin_library",
            ctx.label.name,
        ),
    )

    return [
        DefaultInfo(
            files = depset(srcs),
            runfiles = ctx.runfiles(files = srcs),
        ),
        info,
    ]

odin_library = rule(
    implementation = _odin_library_impl,
    doc = "Groups Odin source files into a library that can be imported by odin_binary targets via collections.",
    attrs = {
        "srcs": attr.label_list(
            doc = "Odin source files. All files must be in the same directory (one Odin package).",
            allow_files = [".odin"],
            mandatory = True,
        ),
        "deps": attr.label_list(
            doc = "Direct Odin library dependencies propagated transitively.",
            providers = [OdinLibraryInfo],
            default = [],
        ),
    },
)
