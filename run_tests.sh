#!/bin/bash

tests_dir=./tests

for test_file in $tests_dir/*tests.lua; do
    echo -e "\033[35mRunning tests for $test_file\033[0m"

    lua $test_file

    echo -e "\033[35mTests finished for $test_file\033[0m"
done
