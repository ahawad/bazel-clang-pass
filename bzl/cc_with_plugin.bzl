load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain", "use_cpp_toolchain")
load("@rules_cc//cc:action_names.bzl", "CPP_LINK_EXECUTABLE_ACTION_NAME", "CPP_LINK_NODEPS_DYNAMIC_LIBRARY_ACTION_NAME", "CPP_LINK_STATIC_LIBRARY_ACTION_NAME", "C_COMPILE_ACTION_NAME")
load(":dict.bzl", "expand_dict_value_locations")

def _is_link_shared(ctx):
    return hasattr(ctx.attr, "linkshared") and ctx.attr.linkshared

def _get_cc_runtimes(ctx, is_library):
    if is_library:
        return []

    runtimes = [ctx.attr.link_extra_lib]

    if ctx.fragments.cpp.custom_malloc != None:
        runtimes.append(ctx.attr._default_malloc)
    else:
        runtimes.append(ctx.attr.malloc)

    return runtimes

def _get_providers(ctx):
    all_deps = ctx.attr.deps + _get_cc_runtimes(ctx, _is_link_shared(ctx))
    return [dep[CcInfo] for dep in all_deps if CcInfo in dep]

def get_cc_user_link_flags(ctx):
    """Get the current target's linkopt flags

    Args:
        ctx (ctx): The current rule's context object

    Returns:
        depset: The flags passed to Bazel by --linkopt option.
    """
    return ctx.fragments.cpp.linkopts

def get_linker_and_args(ctx, attr, binary_type, cc_toolchain, feature_configuration, rpaths):
    """Gathers cc_common linker information

    Args:
        ctx (ctx): The current target's context object
        attr (struct): Attributes to use in gathering linker args
        binary_type (str): The type of binary being linked
        cc_toolchain (CcToolchain): cc_toolchain for which we are creating build variables.
        feature_configuration (FeatureConfiguration): Feature configuration to be queried.
        rpaths (depset): Depset of directories where loader will look for libraries at runtime.

    Returns:
        tuple: A tuple of the following items:
            - (str): The tool path for given action.
            - (sequence): A flattened command line flags for given action.
            - (dict): Environment variables to be set for given action.
    """
    user_link_flags = get_cc_user_link_flags(ctx)

    if binary_type in ("executable"):
        is_linking_dynamic_library = False
        action_name = CPP_LINK_EXECUTABLE_ACTION_NAME
    elif binary_type in ("shared_library"):
        is_linking_dynamic_library = True
        action_name = CPP_LINK_NODEPS_DYNAMIC_LIBRARY_ACTION_NAME
    elif binary_type in ("archive"):
        is_linking_dynamic_library = False
        action_name = CPP_LINK_STATIC_LIBRARY_ACTION_NAME
    else:
        fail("Unknown `binary_type`: {}".format(binary_type))

    # Add linkopt's from dependencies. This includes linkopts from transitive
    # dependencies since they get merged up.
    for dep in getattr(attr, "deps", []):
        if CcInfo in dep and dep[CcInfo].linking_context:
            for linker_input in dep[CcInfo].linking_context.linker_inputs.to_list():
                for flag in linker_input.user_link_flags:
                    user_link_flags.append(flag)
    link_variables = cc_common.create_link_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        is_linking_dynamic_library = is_linking_dynamic_library,
        runtime_library_search_directories = rpaths,
        user_link_flags = user_link_flags,
    )
    link_args = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = action_name,
        variables = link_variables,
    )
    link_env = cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = action_name,
        variables = link_variables,
    )
    ld = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = action_name,
    )

    return ld, link_args, link_env

def _get_compile_vars(ctx, cc_toolchain, source_files, output_file, additional_flags = None):
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
    )

    c_compile_action = C_COMPILE_ACTION_NAME

    # Create the compile variables with only the necessary arguments
    compile_variables = cc_common.create_compile_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        source_file = source_files[0].path,
        output_file = output_file.path,
        user_compile_flags = additional_flags,
    )

    # Generate the command line from the compile variables
    command_line = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = c_compile_action,
        variables = compile_variables,
    )

    env = cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = c_compile_action,
        variables = compile_variables,
    )

    return command_line, None, env

def _cc_binary_with_plugin_impl(ctx):
    cc_toolchain = find_cpp_toolchain(ctx)
    output = ctx.actions.declare_file(ctx.label.name)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
    )
    c_compiler_path = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = C_COMPILE_ACTION_NAME,
    )

    # First, build the plugins
    plugins = []
    for plugin in ctx.attr.plugins:
        print(plugin[CcSharedLibraryInfo].linker_input.libraries[0])
        plugins.append(plugin[CcSharedLibraryInfo].linker_input.libraries[0].dynamic_library)
    source_files = ctx.files.srcs
    object_file = ctx.actions.declare_file(ctx.label.name + ".o")
    plugin_flags = [
        "-fpass-plugin=" + plugin.path
        for plugin in plugins
    ]
    command_line, c_compile_variables, env = _get_compile_vars(ctx, cc_toolchain, source_files, object_file, additional_flags = plugin_flags)

    ctx.actions.run(
        executable = c_compiler_path,
        arguments = command_line,
        env = env,
        inputs = depset(
            source_files,
            transitive = [cc_toolchain.all_files, depset(plugins)],
        ),
        outputs = [object_file],
    )

    # Link the object files into an executable
    compilation_context = cc_common.create_compilation_context()

    compilation_outputs = cc_common.create_compilation_outputs(
        objects = depset([object_file]),
        pic_objects = depset([object_file]),
    )

    out = cc_common.link(
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        compilation_outputs = compilation_outputs,
        name = ctx.label.name,
        output_type = "executable",
    )

    executable = out.executable

    default_info = DefaultInfo(
        files = depset([executable]),
        executable = executable,
    )

    cc_info = cc_common.merge_cc_infos(cc_infos = [
        CcInfo(compilation_context = compilation_context),
    ] + [dep[CcInfo] for dep in ctx.attr.deps])

    return [
        default_info,
        cc_info,
        RunEnvironmentInfo(
            environment = expand_dict_value_locations(
                ctx,
                ctx.attr.env,
                ctx.attr.data,
            ),
        ),
    ]

# Rule declaration:
cc_binary_with_plugin = rule(
    implementation = _cc_binary_with_plugin_impl,
    attrs = {
        "srcs": attr.label_list(mandatory = True, allow_files = [".c", ".cc", ".cpp"]),
        "hdrs": attr.label_list(mandatory = False, allow_files = [".h", ".hh", ".hpp"]),
        "plugins": attr.label_list(allow_files = False, providers = [CcSharedLibraryInfo]),
        "deps": attr.label_list(),
        "_cc_toolchain": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
        "data": attr.label_list(
            allow_files = True,
        ),
        "env": attr.string_dict(
            mandatory = False,
        ),
    },
    provides = [CcInfo, DefaultInfo],
    toolchains = use_cpp_toolchain(),
    executable = True,
    fragments = ["cpp"],
)
