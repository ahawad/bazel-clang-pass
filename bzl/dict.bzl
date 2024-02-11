# The normal ctx.expand_location, but with an additional deduplication step.
# We do this to work around a potential crash, see
# https://github.com/bazelbuild/bazel/issues/16664
def dedup_expand_location(ctx, input, targets = []):
    return ctx.expand_location(input, _deduplicate(targets))

def _deduplicate(xs):
    return {x: True for x in xs}.keys()

def expand_dict_value_locations(ctx, env, data):
    """Performs location-macro expansion on string values.

    $(execroot ...) and $(location ...) are prefixed with ${pwd},
    which process_wrapper and build_script_runner will expand at run time
    to the absolute path. This is necessary because include_str!() is relative
    to the currently compiled file, and build scripts run relative to the
    manifest dir, so we can not use execroot-relative paths.

    $(rootpath ...) is unmodified, and is useful for passing in paths via
    rustc_env that are encoded in the binary with env!(), but utilized at
    runtime, such as in tests. The absolute paths are not usable in this case,
    as compilation happens in a separate sandbox folder, so when it comes time
    to read the file at runtime, the path is no longer valid.

    For detailed documentation, see:
    - [`expand_location`](https://bazel.build/rules/lib/ctx#expand_location)
    - [`expand_make_variables`](https://bazel.build/rules/lib/ctx#expand_make_variables)

    Args:
        ctx (ctx): The rule's context object
        env (dict): A dict whose values we iterate over
        data (sequence of Targets): The targets which may be referenced by
            location macros. This is expected to be the `data` attribute of
            the target, though may have other targets or attributes mixed in.

    Returns:
        dict: A dict of environment variables with expanded location macros
    """
    return dict([(k, _expand_location_for_build_script_runner(ctx, v, data)) for (k, v) in env.items()])

def _expand_location_for_build_script_runner(ctx, env, data):
    """A trivial helper for `expand_dict_value_locations` and `expand_list_element_locations`

    Args:
        ctx (ctx): The rule's context object
        env (str): The value possibly containing location macros to expand.
        data (sequence of Targets): See one of the parent functions.

    Returns:
        string: The location-macro expanded version of the string.
    """
    for directive in ("$(execpath ", "$(location "):
        if directive in env:
            # build script runner will expand pwd to execroot for us
            env = env.replace(directive, "$${pwd}/" + directive)
    return ctx.expand_make_variables(
        env,
        dedup_expand_location(ctx, env, data),
        {},
    )
