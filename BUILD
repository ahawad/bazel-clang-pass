load("@//bzl:cc_with_plugin.bzl", "cc_binary_with_plugin")

cc_import(
    name = "llvm",
    hdrs = ["@llvm_toolchain_llvm//:all_includes"],
    includes = ["external/toolchains_llvm~override~llvm~llvm_toolchain_llvm/include"],
)

cc_library(
    name = "plugin",
    srcs = ["plugin.cpp"],
    deps = [":llvm"]
)

cc_shared_library(
    name = "plugin_lib",
    deps = [":plugin"],
)

cc_binary_with_plugin(
    name = "my_program",
    srcs = ["service.cpp"],
    plugins = [":plugin_lib"],
)
