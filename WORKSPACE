load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

# This file is licensed under the Apache License v2.0 with LLVM Exceptions.
# See https://llvm.org/LICENSE.txt for license information.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

"""An example WORKSPACE for configuring LLVM using http_archive."""

workspace(name = "ear-test")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# Replace with the LLVM commit you want to use.
LLVM_COMMIT = "926f85db98aae66ab8f57b9981f47ddddb868c51"

# The easiest way to calculate this for a new commit is to set it to empty and
# then run a bazel build and it will report the digest necessary to cache the
# archive and make the build reproducible.
LLVM_SHA256 = ""

http_archive(
    name = "llvm-raw",
    build_file_content = "# empty",
    sha256 = LLVM_SHA256,
    strip_prefix = "llvm-project-" + LLVM_COMMIT,
    urls = ["https://github.com/llvm/llvm-project/archive/{commit}.tar.gz".format(commit = LLVM_COMMIT)],
)

load("@llvm-raw//utils/bazel:configure.bzl", "llvm_configure")

llvm_configure(name = "llvm-project")

maybe(
    http_archive,
    name = "llvm_zlib",
    build_file = "@llvm-raw//utils/bazel/third_party_build:zlib-ng.BUILD",
    integrity = "sha256-42uzRsAEcqH5/yoKRkPlkKJUvmN52nzd2drrmn8pZzE=",
    strip_prefix = "zlib-ng-2.0.7",
    urls = [
        "https://github.com/zlib-ng/zlib-ng/archive/refs/tags/2.0.7.zip",
    ],
)

maybe(
    http_archive,
    name = "llvm_zstd",
    build_file = "@llvm-raw//utils/bazel/third_party_build:zstd.BUILD",
    integrity = "sha256-fELVb6wSaSmmqF28c/8dskEdBPEE+um96lEwVmOoP9A=",
    strip_prefix = "zstd-1.5.2",
    urls = [
        "https://github.com/facebook/zstd/releases/download/v1.5.2/zstd-1.5.2.tar.gz",
    ],
)
