load("@//bzl:cc_with_plugin.bzl", "cc_binary_with_plugin")

cc_library(
    name = "plugin",
    srcs = ["plugin.cpp"],
    hdrs = ["plugin.h"],
    deps = [
        "@llvm-project//clang:driver",
        "@llvm-project//clang:frontend",
        "@llvm-project//clang:tooling",
    ],
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
