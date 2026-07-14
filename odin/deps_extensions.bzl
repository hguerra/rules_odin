"""Bzlmod extension for immutable external Odin source dependencies."""

load(
    "//odin/private:deps_repositories.bzl",
    "dependency_download_auth",
    "odin_git_repository",
    "odin_http_repository",
)
load(
    "//odin/private:deps_validation.bzl",
    "normalize_git_alias",
    "normalize_hosted_archive",
    "provider_commit_from_response",
    "provider_resolution_url",
    "validate_dependency_names",
    "validate_git_dependency",
    "validate_hosted_dependency",
    "validate_http_dependency",
)

_http_archive = tag_class(
    attrs = {
        "auth": attr.string(default = "none"),
        "integrity": attr.string(default = ""),
        "name": attr.string(mandatory = True),
        "package_path": attr.string(default = ""),
        "sha256": attr.string(default = ""),
        "source_subdir": attr.string(default = ""),
        "strip_components": attr.int(default = 0),
        "strip_prefix": attr.string(default = ""),
        "urls": attr.string_list(mandatory = True),
    },
)

_hosted_repository_attrs = {
    "commit": attr.string(default = ""),
    "name": attr.string(mandatory = True),
    "package_path": attr.string(default = ""),
    "private": attr.bool(default = False),
    "repository": attr.string(mandatory = True),
    "sha256": attr.string(default = ""),
    "source_subdir": attr.string(default = ""),
    "tag": attr.string(default = ""),
}

_github = tag_class(attrs = _hosted_repository_attrs)
_gitlab = tag_class(attrs = _hosted_repository_attrs)

_git_repository = tag_class(
    attrs = {
        "commit": attr.string(mandatory = True),
        "name": attr.string(mandatory = True),
        "package_path": attr.string(default = ""),
        "remote": attr.string(mandatory = True),
        "source_subdir": attr.string(default = ""),
    },
)

_git = tag_class(
    attrs = {
        "commit": attr.string(mandatory = True),
        "name": attr.string(mandatory = True),
        "package_path": attr.string(default = ""),
        "source_subdir": attr.string(default = ""),
        "url": attr.string(mandatory = True),
    },
)

def _normalized_http(tag):
    return struct(
        archive_type = "",
        auth = tag.auth,
        integrity = tag.integrity,
        name = tag.name,
        package_path = tag.package_path or tag.name,
        sha256 = tag.sha256,
        source_subdir = tag.source_subdir,
        strip_components = tag.strip_components,
        strip_prefix = tag.strip_prefix,
        urls = tag.urls,
    )

def _normalized_git(tag):
    return struct(
        commit = tag.commit,
        name = tag.name,
        package_path = tag.package_path or tag.name,
        remote = tag.remote,
        source_subdir = tag.source_subdir,
    )

def _with_sha256(dep, sha256):
    return struct(
        archive_type = dep.archive_type,
        auth = dep.auth,
        integrity = dep.integrity,
        name = dep.name,
        package_path = dep.package_path,
        sha256 = sha256,
        source_subdir = dep.source_subdir,
        strip_components = dep.strip_components,
        strip_prefix = dep.strip_prefix,
        urls = dep.urls,
    )

def _provider_auth_mode(provider, private):
    if not private:
        return "none"
    return "github_bearer" if provider == "github" else "gitlab_bearer"

def _resolve_provider_commit(module_ctx, tag, provider):
    if tag.commit:
        return tag.commit

    url = provider_resolution_url(provider, tag.repository, tag.tag)
    auth_mode = _provider_auth_mode(provider, tag.private)
    result = module_ctx.download(
        url,
        "_odin_deps/{}/resolution.json".format(tag.name),
        canonical_id = "rules_odin:resolve:v1:{}".format(url),
        auth = dependency_download_auth(module_ctx, [url], auth_mode, tag.name),
    )
    if not result.success:
        fail("rules_odin: dependency '{}' could not resolve tag '{}'".format(tag.name, tag.tag))

    response = json.decode(module_ctx.read("_odin_deps/{}/resolution.json".format(tag.name)))
    commit = provider_commit_from_response(provider, response)
    if not commit:
        fail("rules_odin: dependency '{}' provider returned no full commit for tag '{}'".format(tag.name, tag.tag))
    return commit

def _resolve_hosted_dependency(module_ctx, tag, provider):
    commit = _resolve_provider_commit(module_ctx, tag, provider)
    dep = normalize_hosted_archive(tag, provider, commit)
    if dep.sha256:
        return dep

    result = module_ctx.download(
        dep.urls,
        "_odin_deps/{}/source.tar.gz".format(dep.name),
        canonical_id = "rules_odin:checksum:v1:{}".format(",".join(dep.urls)),
        auth = dependency_download_auth(module_ctx, dep.urls, dep.auth, dep.name),
    )
    if not result.success:
        fail("rules_odin: dependency '{}' archive download failed".format(dep.name))
    return _with_sha256(dep, result.sha256)

def _odin_deps_impl(module_ctx):
    http_dependencies = []
    git_dependencies = []
    hosted_dependencies = []
    root_direct_dependencies = []
    root_direct_dev_dependencies = []
    for module in module_ctx.modules:
        http_dependencies.extend([_normalized_http(tag) for tag in module.tags.http_archive])
        git_dependencies.extend([_normalized_git(tag) for tag in module.tags.git_repository])
        git_dependencies.extend([normalize_git_alias(tag) for tag in module.tags.git])

        for provider, tags in [
            ("github", module.tags.github),
            ("gitlab", module.tags.gitlab),
        ]:
            for tag in tags:
                error = validate_hosted_dependency(tag, provider)
                if error:
                    fail(error)
                hosted_dependencies.append(struct(provider = provider, tag = tag))

        if module.is_root:
            for tag in module.tags.http_archive + module.tags.git_repository + module.tags.git + module.tags.github + module.tags.gitlab:
                if module_ctx.is_dev_dependency(tag):
                    root_direct_dev_dependencies.append(tag.name)
                else:
                    root_direct_dependencies.append(tag.name)

    hosted_names = [struct(name = item.tag.name) for item in hosted_dependencies]
    error = validate_dependency_names(http_dependencies + hosted_names, git_dependencies)
    if error:
        fail(error)
    for dep in http_dependencies:
        error = validate_http_dependency(dep)
        if error:
            fail(error)
    for dep in git_dependencies:
        error = validate_git_dependency(dep)
        if error:
            fail(error)

    for item in hosted_dependencies:
        dep = _resolve_hosted_dependency(module_ctx, item.tag, item.provider)
        error = validate_http_dependency(dep)
        if error:
            fail(error)
        http_dependencies.append(dep)

    for dep in http_dependencies:
        odin_http_repository(
            name = dep.name,
            archive_type = dep.archive_type,
            auth = dep.auth,
            dependency_name = dep.name,
            integrity = dep.integrity,
            package_path = dep.package_path,
            sha256 = dep.sha256,
            source_subdir = dep.source_subdir,
            strip_components = dep.strip_components,
            strip_prefix = dep.strip_prefix,
            urls = dep.urls,
        )
    for dep in git_dependencies:
        odin_git_repository(
            name = dep.name,
            commit = dep.commit,
            dependency_name = dep.name,
            package_path = dep.package_path,
            remote = dep.remote,
            source_subdir = dep.source_subdir,
        )

    return module_ctx.extension_metadata(
        root_module_direct_deps = root_direct_dependencies,
        root_module_direct_dev_deps = root_direct_dev_dependencies,
    )

odin_deps = module_extension(
    implementation = _odin_deps_impl,
    tag_classes = {
        "git": _git,
        "git_repository": _git_repository,
        "github": _github,
        "gitlab": _gitlab,
        "http_archive": _http_archive,
    },
)
