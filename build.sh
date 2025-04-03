#!/bin/bash

# Custom build script (linux shell script).
#
# Usage:
#    ./build.sh: clean, compile and run
#    ./build.sh -clean: clean compiled file
#    ./build.sh -cleanAndCompile: clean compiled file and compile the project
#    ./build.sh -compile: compile the project
#    ./build.sh -compileAndRun: compile the project and run the compiled file
#    ./build.sh -run: run the compiled file
#
# Author: Prof. Dr. David Buzatto

CompiledFile=${PWD##*/}
CompiledFile=${CompiledFile:-/}

clean_project() {
    echo "Cleaning..."
    rm -f $CompiledFile
}

compile_project() {
    echo "Compiling..."
    gcc main.c -o $CompiledFile \
        -O1 \
        -Wall \
        -Wextra \
        -Wno-unused-parameter \
        -pedantic-errors \
        -std=c99 \
        -Wno-missing-braces \
        -I src/include/ \
        -lraylib \
        -lGL \
        -lm \
        -lpthread \
        -ldl \
        -lrt \
        -lX11
}

run_project() {
    echo "Running..."
    if [ -e $CompiledFile ]; then
        ./$CompiledFile
    else
        echo "$CompiledFile does not exists!"
    fi
}

if [ $# -eq 0 ]; then
    clean_project
    compile_project
    run_project
fi

if [ "$1" = "-clean" ]; then
    clean_project
fi

if [ "$1" = "-cleanAndCompile" ]; then
    clean_project
    compile_project
fi

if [ "$1" = "-compile" ]; then
    compile_project
fi

if [ "$1" = "-compileAndRun" ]; then
    compile_project
    run_project
fi

if [ "$1" = "-run" ]; then
    run_project
fi
