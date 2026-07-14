"""Unit tests for dependency declaration validation."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
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

def _http_dependency(**overrides):
    values = {
        "auth": "none",
        "integrity": "",
        "name": "toml_parser",
        "package_path": "toml_parser",
        "sha256": "a" * 64,
        "source_subdir": "",
        "strip_components": 0,
        "strip_prefix": "toml_parser-commit",
        "urls": ["https://github.com/Up05/toml_parser/archive/commit.tar.gz"],
    }
    values.update(overrides)
    return struct(**values)

def _git_dependency(**overrides):
    values = {
        "commit": "a" * 40,
        "name": "toml_parser",
        "package_path": "toml_parser",
        "remote": "https://github.com/Up05/toml_parser.git",
        "source_subdir": "",
    }
    values.update(overrides)
    return struct(**values)

def _hosted_dependency(**overrides):
    values = {
        "commit": "a" * 40,
        "name": "toml_parser",
        "package_path": "",
        "private": False,
        "repository": "Up05/toml_parser",
        "sha256": "",
        "source_subdir": "",
        "tag": "",
    }
    values.update(overrides)
    return struct(**values)

def _valid_http_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(env, None, validate_http_dependency(_http_dependency()))
    asserts.equals(env, None, validate_http_dependency(_http_dependency(
        sha256 = "",
        integrity = "sha256-47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=",
    )))
    asserts.equals(env, None, validate_http_dependency(_http_dependency(
        auth = "github_bearer",
        urls = ["https://api.github.com/repos/acme/parser/tarball/commit"],
    )))
    asserts.equals(env, None, validate_http_dependency(_http_dependency(
        auth = "gitlab_bearer",
        urls = ["https://gitlab.com/api/v4/projects/acme%2Fparser/repository/archive.tar.gz"],
    )))
    asserts.equals(env, None, validate_http_dependency(_http_dependency(
        auth = "netrc_basic",
        urls = ["https://packages.example.com/parser.tar.gz"],
    )))
    return unittest.end(env)

valid_http_test = unittest.make(_valid_http_test_impl)

def _invalid_common_fields_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(env, "rules_odin: dependency 'Bad-Name' attribute 'name' must match [a-z][a-z0-9_]*", validate_http_dependency(_http_dependency(name = "Bad-Name")))
    asserts.equals(env, "rules_odin: dependency 'toml_parser' attribute 'source_subdir' must be a normalized relative path", validate_http_dependency(_http_dependency(source_subdir = "../src")))
    asserts.equals(env, "rules_odin: dependency 'toml_parser' attribute 'package_path' must not contain control characters", validate_http_dependency(_http_dependency(package_path = "parser\ninvalid")))
    return unittest.end(env)

invalid_common_fields_test = unittest.make(_invalid_common_fields_test_impl)

def _invalid_http_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(env, "rules_odin: dependency 'toml_parser' attribute 'sha256' must contain exactly 64 lowercase hexadecimal characters", validate_http_dependency(_http_dependency(sha256 = "abc")))
    asserts.equals(env, "rules_odin: dependency 'toml_parser' attributes 'sha256' and 'integrity' are mutually exclusive", validate_http_dependency(_http_dependency(integrity = "sha256-YQ==")))
    asserts.equals(env, "rules_odin: dependency 'toml_parser' attribute 'integrity' must contain a Base64-encoded SHA-256 digest", validate_http_dependency(_http_dependency(
        sha256 = "",
        integrity = "sha256-not base64!",
    )))
    asserts.equals(env, "rules_odin: dependency 'toml_parser' attribute 'urls' must contain only HTTPS URLs without credentials", validate_http_dependency(_http_dependency(urls = ["https://token@example.com/archive.tar.gz"])))
    asserts.equals(env, "rules_odin: dependency 'toml_parser' attribute 'auth' github_bearer requires api.github.com URLs", validate_http_dependency(_http_dependency(auth = "github_bearer")))
    asserts.equals(env, "rules_odin: dependency 'toml_parser' attribute 'auth' gitlab_bearer requires gitlab.com URLs", validate_http_dependency(_http_dependency(
        auth = "gitlab_bearer",
        urls = ["https://example.com/archive.tar.gz"],
    )))
    return unittest.end(env)

invalid_http_test = unittest.make(_invalid_http_test_impl)

def _git_validation_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(env, None, validate_git_dependency(_git_dependency()))
    asserts.equals(env, None, validate_git_dependency(_git_dependency(remote = "git@gitlab.com:group/project.git")))
    asserts.equals(env, None, validate_git_dependency(_git_dependency(remote = "ssh://git@github.com/acme/project.git")))
    asserts.equals(env, "rules_odin: dependency 'toml_parser' attribute 'commit' must be a 40-character lowercase Git commit", validate_git_dependency(_git_dependency(commit = "main")))
    asserts.equals(env, "rules_odin: dependency 'toml_parser' attribute 'remote' must be HTTPS, SSH, or SCP-style Git without embedded credentials", validate_git_dependency(_git_dependency(remote = "https://token@example.com/project.git")))
    asserts.equals(env, "rules_odin: dependency 'toml_parser' attribute 'remote' must be HTTPS, SSH, or SCP-style Git without embedded credentials", validate_git_dependency(_git_dependency(remote = "ssh://git:password@example.com/project.git")))
    return unittest.end(env)

git_validation_test = unittest.make(_git_validation_test_impl)

def _duplicate_dependency_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(
        env,
        "rules_odin: dependency 'toml_parser' attribute 'name' is declared more than once",
        validate_dependency_names(
            [_http_dependency()],
            [_git_dependency()],
        ),
    )
    return unittest.end(env)

duplicate_dependency_test = unittest.make(_duplicate_dependency_test_impl)

def _hosted_validation_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(env, None, validate_hosted_dependency(_hosted_dependency(), "github"))
    asserts.equals(env, None, validate_hosted_dependency(_hosted_dependency(
        commit = "",
        repository = "group/subgroup/parser",
        tag = "v1.2.0",
    ), "gitlab"))
    asserts.equals(
        env,
        "rules_odin: dependency 'toml_parser' requires exactly one of 'commit' or 'tag'",
        validate_hosted_dependency(_hosted_dependency(commit = "", tag = ""), "github"),
    )
    asserts.equals(
        env,
        "rules_odin: dependency 'toml_parser' attributes 'commit' and 'tag' are mutually exclusive",
        validate_hosted_dependency(_hosted_dependency(tag = "v1.2.0"), "github"),
    )
    asserts.equals(
        env,
        "rules_odin: dependency 'toml_parser' attribute 'repository' must be an owner/repository slug",
        validate_hosted_dependency(_hosted_dependency(repository = "https://github.com/Up05/toml_parser"), "github"),
    )
    asserts.equals(
        env,
        "rules_odin: dependency 'toml_parser' attribute 'repository' must be a group/project slug",
        validate_hosted_dependency(_hosted_dependency(repository = "group/../parser"), "gitlab"),
    )
    asserts.equals(
        env,
        "rules_odin: dependency 'toml_parser' attribute 'sha256' must contain exactly 64 lowercase hexadecimal characters",
        validate_hosted_dependency(_hosted_dependency(sha256 = "abc"), "github"),
    )
    return unittest.end(env)

hosted_validation_test = unittest.make(_hosted_validation_test_impl)

def _provider_normalization_test_impl(ctx):
    env = unittest.begin(ctx)
    commit = "a" * 40

    github = normalize_hosted_archive(_hosted_dependency(), "github", commit)
    asserts.equals(env, ["https://github.com/Up05/toml_parser/archive/{}.tar.gz".format(commit)], github.urls)
    asserts.equals(env, "toml_parser-{}".format(commit), github.strip_prefix)
    asserts.equals(env, 0, github.strip_components)
    asserts.equals(env, "none", github.auth)
    asserts.equals(env, "toml_parser", github.package_path)
    asserts.equals(env, "", github.sha256)

    private_github = normalize_hosted_archive(_hosted_dependency(private = True), "github", commit)
    asserts.equals(env, ["https://api.github.com/repos/Up05/toml_parser/tarball/{}".format(commit)], private_github.urls)
    asserts.equals(env, "", private_github.strip_prefix)
    asserts.equals(env, 1, private_github.strip_components)
    asserts.equals(env, "github_bearer", private_github.auth)
    asserts.equals(env, "tar.gz", private_github.archive_type)

    gitlab = normalize_hosted_archive(_hosted_dependency(repository = "group/subgroup/parser"), "gitlab", commit)
    asserts.equals(env, ["https://gitlab.com/group/subgroup/parser/-/archive/{0}/parser-{0}.tar.gz".format(commit)], gitlab.urls)
    asserts.equals(env, "parser-{}".format(commit), gitlab.strip_prefix)

    private_gitlab = normalize_hosted_archive(_hosted_dependency(
        private = True,
        repository = "group/subgroup/parser",
    ), "gitlab", commit)
    asserts.equals(env, ["https://gitlab.com/api/v4/projects/group%2Fsubgroup%2Fparser/repository/archive.tar.gz?sha={}".format(commit)], private_gitlab.urls)
    asserts.equals(env, "gitlab_bearer", private_gitlab.auth)
    asserts.equals(env, 1, private_gitlab.strip_components)

    return unittest.end(env)

provider_normalization_test = unittest.make(_provider_normalization_test_impl)

def _provider_resolution_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(
        env,
        "https://api.github.com/repos/Up05/toml_parser/commits/v1.2.0",
        provider_resolution_url("github", "Up05/toml_parser", "v1.2.0"),
    )
    asserts.equals(
        env,
        "https://gitlab.com/api/v4/projects/group%2Fsubgroup%2Fparser/repository/commits/release%2F1.2",
        provider_resolution_url("gitlab", "group/subgroup/parser", "release/1.2"),
    )

    git = normalize_git_alias(struct(
        commit = "a" * 40,
        name = "toml_parser",
        package_path = "",
        source_subdir = "",
        url = "git@github.com:Up05/toml_parser.git",
    ))
    asserts.equals(env, "git@github.com:Up05/toml_parser.git", git.remote)
    asserts.equals(env, "toml_parser", git.package_path)

    asserts.equals(
        env,
        "a" * 40,
        provider_commit_from_response("github", {"sha": "a" * 40}),
    )
    asserts.equals(
        env,
        "b" * 40,
        provider_commit_from_response("gitlab", {"id": "b" * 40}),
    )
    asserts.equals(env, None, provider_commit_from_response("github", {"sha": "main"}))
    asserts.equals(env, None, provider_commit_from_response("gitlab", {"message": "not found"}))
    return unittest.end(env)

provider_resolution_test = unittest.make(_provider_resolution_test_impl)

def deps_validation_test_suite(name):
    """Declare the complete dependency validation test suite.

    Args:
      name: Name for the generated native test suite.
    """
    valid_http_test(name = "valid_http_test")
    invalid_common_fields_test(name = "invalid_common_fields_test")
    invalid_http_test(name = "invalid_http_test")
    git_validation_test(name = "git_validation_test")
    duplicate_dependency_test(name = "duplicate_dependency_test")
    hosted_validation_test(name = "hosted_validation_test")
    provider_normalization_test(name = "provider_normalization_test")
    provider_resolution_test(name = "provider_resolution_test")
    native.test_suite(
        name = name,
        tests = [
            ":valid_http_test",
            ":invalid_common_fields_test",
            ":invalid_http_test",
            ":git_validation_test",
            ":duplicate_dependency_test",
            ":hosted_validation_test",
            ":provider_normalization_test",
            ":provider_resolution_test",
        ],
    )
