"""Private repository rules for immutable external Odin dependencies."""

load("@bazel_tools//tools/build_defs/repo:git_worker.bzl", "git_repo")
load(
    "@bazel_tools//tools/build_defs/repo:utils.bzl",
    "read_netrc",
    "read_user_netrc",
    "use_netrc",
)

_BEARER_PATTERNS = {
    "github_bearer": {"api.github.com": "Bearer <password>"},
    "gitlab_bearer": {"gitlab.com": "Bearer <password>"},
}

def _url_host(url):
    return url.split("://", 1)[1].split("/", 1)[0].split(":", 1)[0]

def _read_netrc_for_auth(ctx, dependency_name):
    if "NETRC" in ctx.os.environ:
        netrc = read_netrc(ctx, ctx.os.environ["NETRC"])
    else:
        netrc = read_user_netrc(ctx)
    if "" in netrc:
        fail("rules_odin: dependency '{}' auth rejects a default .netrc entry".format(
            dependency_name,
        ))
    return netrc

def dependency_download_auth(ctx, urls, auth_mode, dependency_name):
    """Return host-scoped download auth without exposing credential attributes.

    Args:
      ctx: Repository rule context used to read the local netrc file.
      urls: HTTPS download URLs requiring authentication.
      auth_mode: Configured authentication mode.
      dependency_name: Dependency name used in safe error messages.

    Returns:
      A Bazel download authentication mapping.
    """
    if auth_mode == "none":
        return {}

    netrc = _read_netrc_for_auth(ctx, dependency_name)
    for url in urls:
        host = _url_host(url)
        if host not in netrc or "password" not in netrc[host]:
            fail("rules_odin: dependency '{}' auth has no password for host '{}' in .netrc".format(
                dependency_name,
                host,
            ))
        if auth_mode == "netrc_basic" and "login" not in netrc[host]:
            fail("rules_odin: dependency '{}' auth netrc_basic requires a login for host '{}'".format(
                dependency_name,
                host,
            ))

    patterns = _BEARER_PATTERNS.get(auth_mode, {})
    return use_netrc(netrc, urls, patterns)

def _download_auth(ctx):
    return dependency_download_auth(
        ctx,
        ctx.attr.urls,
        ctx.attr.auth,
        ctx.attr.dependency_name,
    )

def _collection_build(name):
    return """load("@rules_odin//odin:defs.bzl", "odin_collection")

package(default_visibility = ["//visibility:public"])

odin_collection(
    name = {name},
    srcs = glob(["odin_deps/**/*.odin"]),
    collection_root = "odin_deps",
)
""".format(name = repr(name))

def _canonical_id(ctx):
    digest = ctx.attr.sha256 or ctx.attr.integrity
    return "rules_odin:http:v1:{}:{}:{}:{}:{}".format(
        ",".join(ctx.attr.urls),
        digest,
        ctx.attr.strip_prefix,
        ctx.attr.strip_components,
        ctx.attr.source_subdir,
    )

def _odin_http_repository_impl(ctx):
    ctx.download_and_extract(
        ctx.attr.urls,
        "_upstream",
        ctx.attr.sha256,
        ctx.attr.archive_type,
        ctx.attr.strip_prefix,
        strip_components = ctx.attr.strip_components,
        canonical_id = _canonical_id(ctx),
        auth = _download_auth(ctx),
        integrity = ctx.attr.integrity,
    )

    source = ctx.path("_upstream")
    if ctx.attr.source_subdir:
        source = source.get_child(ctx.attr.source_subdir)
    if not source.exists or not source.is_dir:
        fail("rules_odin: dependency '{}' source_subdir '{}' is not a directory".format(
            ctx.attr.dependency_name,
            ctx.attr.source_subdir,
        ))

    destination = ctx.path("odin_deps").get_child(ctx.attr.package_path)
    ctx.symlink(source, destination)

    ctx.file("BUILD.bazel", _collection_build(ctx.attr.dependency_name))
    ctx.file("REPO.bazel", "repo(default_package_metadata = [])\n")

odin_http_repository = repository_rule(
    implementation = _odin_http_repository_impl,
    attrs = {
        "archive_type": attr.string(),
        "auth": attr.string(mandatory = True),
        "dependency_name": attr.string(mandatory = True),
        "integrity": attr.string(),
        "package_path": attr.string(mandatory = True),
        "sha256": attr.string(),
        "source_subdir": attr.string(),
        "strip_components": attr.int(),
        "strip_prefix": attr.string(),
        "urls": attr.string_list(mandatory = True),
    },
    environ = ["HOME", "NETRC", "USERPROFILE"],
)

def _odin_git_repository_impl(ctx):
    checkout = ctx.path("_upstream")
    result = git_repo(ctx, checkout)
    if result.commit != ctx.attr.commit:
        fail("rules_odin: dependency '{}' commit resolved to unexpected revision '{}'".format(
            ctx.attr.dependency_name,
            result.commit,
        ))

    source = checkout
    if ctx.attr.source_subdir:
        source = source.get_child(ctx.attr.source_subdir)
    if not source.exists or not source.is_dir:
        fail("rules_odin: dependency '{}' source_subdir '{}' is not a directory".format(
            ctx.attr.dependency_name,
            ctx.attr.source_subdir,
        ))

    destination = ctx.path("odin_deps").get_child(ctx.attr.package_path)
    ctx.symlink(source, destination)
    ctx.file("BUILD.bazel", _collection_build(ctx.attr.dependency_name))
    ctx.file("REPO.bazel", "repo(default_package_metadata = [])\n")
    ctx.delete(checkout.get_child(".git"))
    return ctx.repo_metadata(reproducible = True)

odin_git_repository = repository_rule(
    implementation = _odin_git_repository_impl,
    attrs = {
        "branch": attr.string(default = ""),
        "commit": attr.string(mandatory = True),
        "dependency_name": attr.string(mandatory = True),
        "init_submodules": attr.bool(default = False),
        "package_path": attr.string(mandatory = True),
        "recursive_init_submodules": attr.bool(default = False),
        "remote": attr.string(mandatory = True),
        "shallow_since": attr.string(default = ""),
        "source_subdir": attr.string(),
        "strip_prefix": attr.string(default = ""),
        "tag": attr.string(default = ""),
        "verbose": attr.bool(default = False),
    },
    environ = [
        "GIT_CONFIG_GLOBAL",
        "GIT_TERMINAL_PROMPT",
        "HOME",
        "SSH_AUTH_SOCK",
        "USERPROFILE",
    ],
)
