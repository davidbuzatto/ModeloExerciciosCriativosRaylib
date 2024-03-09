# make build script.
#
# usage:
#    make: clean, compile and run
#    make clean: clean compiled file
#    make cleanAndCompile: clean compiled file and compile the project
#    make compile: compile the project
#    make compileAndRun: compile the project and run the compiled file
#    make run: run the compiled file
#
# author: Prof. Dr. David Buzatto

currentFolderName := $(lastword $(notdir $(shell pwd)))
compiledFile := $(currentFolderName).exe
CFLAGS := -O1 -Wall -Wextra -Wno-unused-parameter -pedantic-errors -std=c99 -Wno-missing-braces -I include/ -L lib/ -lraylib -lopengl32 -lgdi32 -lwinmm

all: clean compile run

clean:
	rm -f $(compiledFile)

compile:
	gcc *.c -o $(compiledFile) $(CFLAGS)

run:
	./$(compiledFile)

cleanAndCompile: clean compile
compileAndRun: compile run