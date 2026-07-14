"""Pure validation helpers for Odin dependency declarations."""

_HEX = "0123456789abcdef"
_NAME_HEAD = "abcdefghijklmnopqrstuvwxyz"
_NAME_TAIL = _NAME_HEAD + "0123456789_"
_AUTH_MODES = ["none", "netrc_basic", "github_bearer", "gitlab_bearer"]
_BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
_SLUG_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.-"
_TAG_CHARS = _SLUG_CHARS + "/+"

def _error(name, attribute, message):
    return "rules_odin: dependency '{}' attribute '{}' {}".format(name, attribute, message)

def _has_control(value):
    return "\n" in value or "\r" in value or "\t" in value

def _is_valid_name(value):
    if not value or value[0] not in _NAME_HEAD:
        return False
    for index in range(1, len(value)):
        if value[index] not in _NAME_TAIL:
            return False
    return True

def _path_error(name, attribute, value, allow_empty):
    if not value:
        return None if allow_empty else _error(name, attribute, "must not be empty")
    if _has_control(value):
        return _error(name, attribute, "must not contain control characters")
    if value.startswith("/") or "\\" in value or "//" in value:
        return _error(name, attribute, "must be a normalized relative path")
    for part in value.split("/"):
        if part in ["", ".", ".."]:
            return _error(name, attribute, "must be a normalized relative path")
    return None

def _common_error(dep):
    if not _is_valid_name(dep.name):
        return _error(dep.name, "name", "must match [a-z][a-z0-9_]*")
    error = _path_error(dep.name, "source_subdir", dep.source_subdir, True)
    if error:
        return error
    return _path_error(dep.name, "package_path", dep.package_path, False)

def _is_lower_hex(value, length):
    if len(value) != length:
        return False
    for index in range(len(value)):
        if value[index] not in _HEX:
            return False
    return True

def _valid_repository_slug(value, provider):
    if _has_control(value) or "://" in value or "?" in value or "#" in value or "@" in value:
        return False
    parts = value.split("/")
    if len(parts) < 2 or (provider == "github" and len(parts) != 2):
        return False
    for part in parts:
        if not part or part in [".", ".."]:
            return False
        for index in range(len(part)):
            if part[index] not in _SLUG_CHARS:
                return False
    return True

def _valid_tag(value):
    if not value or _has_control(value) or value.startswith("/") or value.endswith("/") or "//" in value:
        return False
    for index in range(len(value)):
        if value[index] not in _TAG_CHARS:
            return False
    return True

def _encode_tag(value):
    return value.replace("+", "%2B").replace("/", "%2F")

def _encoded_project(repository):
    return repository.replace("/", "%2F")

def _https_host(url):
    if _has_control(url) or not url.startswith("https://"):
        return None
    authority = url[len("https://"):].split("/", 1)[0]
    if not authority or "@" in authority:
        return None
    return authority

def _valid_sha256_integrity(value):
    if not value.startswith("sha256-"):
        return False
    payload = value[len("sha256-"):]
    if len(payload) != 44 or not payload.endswith("="):
        return False
    for index in range(43):
        if payload[index] not in _BASE64:
            return False
    return True

def validate_http_dependency(dep):
    """Validate an HTTP dependency declaration.

    Args:
      dep: HTTP dependency tag to validate.

    Returns:
      An error string when invalid, otherwise None.
    """
    error = _common_error(dep)
    if error:
        return error
    if not dep.urls:
        return _error(dep.name, "urls", "must contain at least one HTTPS URL")
    hosts = []
    for url in dep.urls:
        host = _https_host(url)
        if not host:
            return _error(dep.name, "urls", "must contain only HTTPS URLs without credentials")
        hosts.append(host)
    if dep.sha256 and dep.integrity:
        return "rules_odin: dependency '{}' attributes 'sha256' and 'integrity' are mutually exclusive".format(dep.name)
    if not dep.sha256 and not dep.integrity:
        return "rules_odin: dependency '{}' requires exactly one of 'sha256' or 'integrity'".format(dep.name)
    if dep.sha256 and not _is_lower_hex(dep.sha256, 64):
        return _error(dep.name, "sha256", "must contain exactly 64 lowercase hexadecimal characters")
    if dep.integrity and not _valid_sha256_integrity(dep.integrity):
        return _error(dep.name, "integrity", "must contain a Base64-encoded SHA-256 digest")
    error = _path_error(dep.name, "strip_prefix", dep.strip_prefix, True)
    if error:
        return error
    if dep.strip_components < 0:
        return _error(dep.name, "strip_components", "must be zero or greater")
    if dep.strip_prefix and dep.strip_components:
        return "rules_odin: dependency '{}' attributes 'strip_prefix' and 'strip_components' are mutually exclusive".format(dep.name)
    if dep.auth not in _AUTH_MODES:
        return _error(dep.name, "auth", "must be one of none, netrc_basic, github_bearer, or gitlab_bearer")
    if dep.auth == "github_bearer" and hosts != ["api.github.com"] * len(hosts):
        return _error(dep.name, "auth", "github_bearer requires api.github.com URLs")
    if dep.auth == "gitlab_bearer" and hosts != ["gitlab.com"] * len(hosts):
        return _error(dep.name, "auth", "gitlab_bearer requires gitlab.com URLs")
    return None

def _valid_git_remote(remote):
    if _has_control(remote):
        return False
    if remote.startswith("https://"):
        return _https_host(remote) != None
    if remote.startswith("ssh://"):
        authority = remote[len("ssh://"):].split("/", 1)[0]
        userinfo = authority.split("@", 1)[0] if "@" in authority else ""
        return bool(authority) and ":" not in userinfo
    if "://" not in remote and ":" in remote:
        host, path = remote.split(":", 1)
        return "@" in host and bool(host.split("@", 1)[1]) and bool(path)
    return False

def validate_git_dependency(dep):
    """Validate an exact-commit Git dependency declaration.

    Args:
      dep: Git dependency tag to validate.

    Returns:
      An error string when invalid, otherwise None.
    """
    error = _common_error(dep)
    if error:
        return error
    if not _is_lower_hex(dep.commit, 40):
        return _error(dep.name, "commit", "must be a 40-character lowercase Git commit")
    if not _valid_git_remote(dep.remote):
        return _error(dep.name, "remote", "must be HTTPS, SSH, or SCP-style Git without embedded credentials")
    return None

def validate_hosted_dependency(dep, provider):
    """Validate a GitHub or GitLab convenience dependency tag.

    Args:
      dep: Hosted dependency tag to validate.
      provider: Expected hosting provider, github or gitlab.

    Returns:
      An error string when invalid, otherwise None.
    """
    normalized = struct(
        name = dep.name,
        package_path = dep.package_path or dep.name,
        source_subdir = dep.source_subdir,
    )
    error = _common_error(normalized)
    if error:
        return error
    if provider not in ["github", "gitlab"]:
        return _error(dep.name, "provider", "must be github or gitlab")
    if not _valid_repository_slug(dep.repository, provider):
        expected = "an owner/repository slug" if provider == "github" else "a group/project slug"
        return _error(dep.name, "repository", "must be {}".format(expected))
    if dep.commit and dep.tag:
        return "rules_odin: dependency '{}' attributes 'commit' and 'tag' are mutually exclusive".format(dep.name)
    if not dep.commit and not dep.tag:
        return "rules_odin: dependency '{}' requires exactly one of 'commit' or 'tag'".format(dep.name)
    if dep.commit and not _is_lower_hex(dep.commit, 40):
        return _error(dep.name, "commit", "must be a 40-character lowercase Git commit")
    if dep.tag and not _valid_tag(dep.tag):
        return _error(dep.name, "tag", "must contain only letters, digits, '.', '_', '-', '/', or '+'")
    if dep.sha256 and not _is_lower_hex(dep.sha256, 64):
        return _error(dep.name, "sha256", "must contain exactly 64 lowercase hexadecimal characters")
    return None

def provider_resolution_url(provider, repository, tag):
    """Build the fixed provider API URL used to resolve a tag to a commit."""
    if provider == "github":
        return "https://api.github.com/repos/{}/commits/{}".format(repository, _encode_tag(tag))
    return "https://gitlab.com/api/v4/projects/{}/repository/commits/{}".format(
        _encoded_project(repository),
        _encode_tag(tag),
    )

def provider_commit_from_response(provider, response):
    """Return a validated full commit from a decoded provider API response."""
    attribute = "sha" if provider == "github" else "id"
    commit = response.get(attribute, "") if type(response) == "dict" else ""
    return commit if _is_lower_hex(commit, 40) else None

def normalize_hosted_archive(dep, provider, resolved_commit):
    """Convert a validated hosted dependency to the HTTP archive model.

    Args:
      dep: Validated hosted dependency tag.
      provider: Hosting provider, github or gitlab.
      resolved_commit: Full immutable commit selected for the archive.

    Returns:
      An HTTP dependency struct suitable for repository creation.
    """
    project = dep.repository.split("/")[-1]
    if provider == "github":
        if dep.private:
            urls = ["https://api.github.com/repos/{}/tarball/{}".format(dep.repository, resolved_commit)]
            auth = "github_bearer"
            strip_components = 1
            strip_prefix = ""
        else:
            urls = ["https://github.com/{}/archive/{}.tar.gz".format(dep.repository, resolved_commit)]
            auth = "none"
            strip_components = 0
            strip_prefix = "{}-{}".format(project, resolved_commit)
    elif dep.private:
        urls = ["https://gitlab.com/api/v4/projects/{}/repository/archive.tar.gz?sha={}".format(
            _encoded_project(dep.repository),
            resolved_commit,
        )]
        auth = "gitlab_bearer"
        strip_components = 1
        strip_prefix = ""
    else:
        urls = ["https://gitlab.com/{0}/-/archive/{1}/{2}-{1}.tar.gz".format(
            dep.repository,
            resolved_commit,
            project,
        )]
        auth = "none"
        strip_components = 0
        strip_prefix = "{}-{}".format(project, resolved_commit)

    return struct(
        archive_type = "tar.gz",
        auth = auth,
        integrity = "",
        name = dep.name,
        package_path = dep.package_path or dep.name,
        sha256 = dep.sha256,
        source_subdir = dep.source_subdir,
        strip_components = strip_components,
        strip_prefix = strip_prefix,
        urls = urls,
    )

def normalize_git_alias(dep):
    """Convert the concise Git tag to the existing exact-commit Git model."""
    return struct(
        commit = dep.commit,
        name = dep.name,
        package_path = dep.package_path or dep.name,
        remote = dep.url,
        source_subdir = dep.source_subdir,
    )

def validate_dependency_names(http_dependencies, git_dependencies):
    """Validate that generated repository names are unique.

    Args:
      http_dependencies: Normalized HTTP dependency declarations.
      git_dependencies: Normalized Git dependency declarations.

    Returns:
      An error string for a duplicate name, otherwise None.
    """
    seen = {}
    for dep in http_dependencies + git_dependencies:
        if dep.name in seen:
            return _error(dep.name, "name", "is declared more than once")
        seen[dep.name] = True
    return None
