# =============================================================================
# Cross-platform Makefile for C/C++ projects with raylib
# Based on:
#   https://makefiletutorial.com/
#   https://spin.atomicobject.com/2016/08/26/makefile-c-projects/
#
# Usage:
#   make               - compile and run the project
#   make compile       - compile the project only
#   make run           - run the compiled binary only
#   make clean         - remove build artifacts
#   make cleanAndCompile - clean and recompile from scratch
#
# Compatible with: Linux, macOS and Windows (MSYS2 and native cmd.exe/MinGW)
# Author: Prof. Dr. David Buzatto
# =============================================================================


# -----------------------------------------------------------------------------
# OPERATING SYSTEM DETECTION
#
# Detection here must handle a subtle detail: MSYS2 filters out some Windows
# environment variables (such as OS=Windows_NT) before passing them to make.
# Therefore $(OS) is available in native cmd.exe but NOT in MSYS2. We start
# with `uname -s`, which works on Linux, macOS and any Unix-like shell on
# Windows (MSYS2, Cygwin, Git Bash). If uname is not available (pure cmd.exe),
# the string comes back empty and we fall through to the $(OS) test to detect
# native Windows.
#
# We classify into four distinct environments:
#   - Linux          : native Linux
#   - macOS          : macOS (Darwin)
#   - Windows_MSYS2  : Windows running inside a Unix shell (MSYS2, Cygwin,
#                      Git Bash). Unix commands (mkdir -p, rm -rf) work;
#                      binary has .exe extension.
#   - Windows_Native : Windows running in cmd.exe without a Unix layer. Needs
#                      cmd commands (if not exist, rmdir /s /q); binary is .exe.
#
# IS_WINDOWS is a derived flag used further below to decide whether to append
# ".exe" to the executable name.
# -----------------------------------------------------------------------------
UNAME_S := $(shell uname -s 2>/dev/null)

ifeq ($(UNAME_S), Linux)
    DETECTED_OS := Linux
    IS_WINDOWS  := 0
else ifeq ($(UNAME_S), Darwin)
    DETECTED_OS := macOS
    IS_WINDOWS  := 0
else ifneq ($(filter MINGW% MSYS% CYGWIN%, $(UNAME_S)),)
    # uname returns strings like "MINGW64_NT-10.0-19045", "MSYS_NT-..." or
    # "CYGWIN_NT-..." when running inside a Unix shell on top of Windows.
    DETECTED_OS := Windows_MSYS2
    IS_WINDOWS  := 1
else ifeq ($(OS), Windows_NT)
    # No uname available, but $(OS) reached make: native cmd.exe.
    DETECTED_OS := Windows_Native
    IS_WINDOWS  := 1
else
    DETECTED_OS := Unknown
    IS_WINDOWS  := 0
endif

# -----------------------------------------------------------------------------
# FORCE SHELL ON NATIVE WINDOWS
#
# On native Windows, if a `sh.exe` is on the PATH (very common when Git is
# installed), GNU Make tends to pick it automatically as the execution shell.
# This would break our recipes written in cmd syntax (if not exist,
# rmdir /s /q). To guarantee cmd.exe is used, we explicitly set SHELL and
# SHELLFLAGS in this case.
# -----------------------------------------------------------------------------
ifeq ($(DETECTED_OS), Windows_Native)
    SHELL       := cmd.exe
    .SHELLFLAGS := /C
endif


# -----------------------------------------------------------------------------
# EXECUTABLE NAME
#
# $(CURDIR) is a GNU Make built-in variable holding the absolute path of the
# current directory. It is more portable than `$(shell pwd)` because it does
# not need to invoke the shell.
#
# $(subst \,/,...) normalises Windows backslashes to forward slashes so that
# path handling works consistently on every platform.
#
# Handling spaces in the project path
# ------------------------------------
# make treats whitespace as a separator between "words". A naive
# $(notdir $(CURDIR)) on a path like "/c/foo/test platform game"
# would be interpreted as several separate items ("test", "platform",
# "game"), and using them as a target would cause make to build
# one executable per word (test.exe, platform.exe, ...). This happens
# both when a parent directory and when the project directory itself
# contain spaces.
#
# To work around this limitation we follow a three-step substitution:
#   1. Replace every literal space in the path with a unique placeholder
#      token (__SP__) that make cannot mistake for a separator.
#   2. Run $(notdir ...) on the escaped path to extract the last component.
#   3. Replace the placeholder with an underscore in the resulting name,
#      producing a single-word executable name that make handles safely.
#
# The `space` variable is a classic make idiom: concatenating two empty
# variables with a literal space between them yields exactly one space,
# which can then be used as the "from" argument of $(subst ...).
#
# On Windows, GCC expects ".exe" in the output binary name.
# -----------------------------------------------------------------------------
empty :=
space := $(empty) $(empty)

# Normalise slashes, then escape spaces with a placeholder before notdir.
__ESCAPED_PATH := $(subst $(space),__SP__,$(subst \,/,$(CURDIR)))

# Extract the directory name from the escaped path, then unescape using '_'.
# The resulting TARGET_NAME is always a single make word (no embedded spaces).
TARGET_NAME := $(subst __SP__,_,$(notdir $(__ESCAPED_PATH)))

# Sanitize accented characters in TARGET_NAME
# -------------------------------------------
# When the project path contains accented letters (common in Portuguese,
# e.g. "espaços", "Área de Trabalho"), the UTF-8 bytes of those letters
# traverse several layers on their way to GCC (make -> cmd.exe -> GCC ->
# filesystem), and on Windows they may be reinterpreted under a different
# codepage (CP850 / CP1252), producing mojibake in the resulting file
# name. The `make run` target would then try to execute the original UTF-8
# name while the actual file on disk has different bytes, and the launch
# fails.
#
# The safest cross-platform fix is to strip accents from TARGET_NAME,
# mapping each accented letter to its plain ASCII equivalent. The resulting
# executable name contains only ASCII characters, which every toolchain
# handles consistently regardless of the active codepage.
#
# Technical note: this works because this Makefile is saved as UTF-8, so
# the literal "ç" below is stored as the same two bytes (0xC3 0xA7) that
# appear in $(CURDIR). If you ever re-save this file in a legacy encoding
# (e.g. Windows-1252), the matches will stop working. Stick to UTF-8.
#
# If your language needs letters that are not listed below, just append
# another `TARGET_NAME := $(subst <letter>,<replacement>,$(TARGET_NAME))`
# line. The order does not matter.
TARGET_NAME := $(subst á,a,$(TARGET_NAME))
TARGET_NAME := $(subst à,a,$(TARGET_NAME))
TARGET_NAME := $(subst ã,a,$(TARGET_NAME))
TARGET_NAME := $(subst â,a,$(TARGET_NAME))
TARGET_NAME := $(subst ä,a,$(TARGET_NAME))
TARGET_NAME := $(subst é,e,$(TARGET_NAME))
TARGET_NAME := $(subst è,e,$(TARGET_NAME))
TARGET_NAME := $(subst ê,e,$(TARGET_NAME))
TARGET_NAME := $(subst ë,e,$(TARGET_NAME))
TARGET_NAME := $(subst í,i,$(TARGET_NAME))
TARGET_NAME := $(subst ì,i,$(TARGET_NAME))
TARGET_NAME := $(subst î,i,$(TARGET_NAME))
TARGET_NAME := $(subst ï,i,$(TARGET_NAME))
TARGET_NAME := $(subst ó,o,$(TARGET_NAME))
TARGET_NAME := $(subst ò,o,$(TARGET_NAME))
TARGET_NAME := $(subst õ,o,$(TARGET_NAME))
TARGET_NAME := $(subst ô,o,$(TARGET_NAME))
TARGET_NAME := $(subst ö,o,$(TARGET_NAME))
TARGET_NAME := $(subst ú,u,$(TARGET_NAME))
TARGET_NAME := $(subst ù,u,$(TARGET_NAME))
TARGET_NAME := $(subst û,u,$(TARGET_NAME))
TARGET_NAME := $(subst ü,u,$(TARGET_NAME))
TARGET_NAME := $(subst ç,c,$(TARGET_NAME))
TARGET_NAME := $(subst ñ,n,$(TARGET_NAME))
TARGET_NAME := $(subst Á,A,$(TARGET_NAME))
TARGET_NAME := $(subst À,A,$(TARGET_NAME))
TARGET_NAME := $(subst Ã,A,$(TARGET_NAME))
TARGET_NAME := $(subst Â,A,$(TARGET_NAME))
TARGET_NAME := $(subst Ä,A,$(TARGET_NAME))
TARGET_NAME := $(subst É,E,$(TARGET_NAME))
TARGET_NAME := $(subst È,E,$(TARGET_NAME))
TARGET_NAME := $(subst Ê,E,$(TARGET_NAME))
TARGET_NAME := $(subst Ë,E,$(TARGET_NAME))
TARGET_NAME := $(subst Í,I,$(TARGET_NAME))
TARGET_NAME := $(subst Ì,I,$(TARGET_NAME))
TARGET_NAME := $(subst Î,I,$(TARGET_NAME))
TARGET_NAME := $(subst Ï,I,$(TARGET_NAME))
TARGET_NAME := $(subst Ó,O,$(TARGET_NAME))
TARGET_NAME := $(subst Ò,O,$(TARGET_NAME))
TARGET_NAME := $(subst Õ,O,$(TARGET_NAME))
TARGET_NAME := $(subst Ô,O,$(TARGET_NAME))
TARGET_NAME := $(subst Ö,O,$(TARGET_NAME))
TARGET_NAME := $(subst Ú,U,$(TARGET_NAME))
TARGET_NAME := $(subst Ù,U,$(TARGET_NAME))
TARGET_NAME := $(subst Û,U,$(TARGET_NAME))
TARGET_NAME := $(subst Ü,U,$(TARGET_NAME))
TARGET_NAME := $(subst Ç,C,$(TARGET_NAME))
TARGET_NAME := $(subst Ñ,N,$(TARGET_NAME))

ifeq ($(IS_WINDOWS), 1)
    TARGET_EXEC := $(TARGET_NAME).exe
else
    TARGET_EXEC := $(TARGET_NAME)
endif


# -----------------------------------------------------------------------------
# MAIN DIRECTORIES
# -----------------------------------------------------------------------------
BUILD_DIR := build
SRC_DIRS  := src


# -----------------------------------------------------------------------------
# HELPER FUNCTION: RECURSIVE FILE SEARCH (rwildcard)
#
# Replaces the Unix shell `find` command, which is unavailable on native
# Windows. Implemented in pure make (no shell invocation), so it works on
# every supported platform.
#
# Usage: $(call rwildcard, ROOT_DIRECTORY, SPACE-SEPARATED_PATTERNS)
#   Example: $(call rwildcard, src, *.c *.cpp)
#
# Step-by-step explanation:
#   $(wildcard $(1:=/*))         → lists all items (files and directories)
#                                   directly inside directory $(1).
#                                   The ":=/*" suffix appends "/*" to the
#                                   directory name to form the correct pattern.
#   $(call rwildcard, $d, $2)    → recursive call for each item $d.
#                                   Make keeps descending into subdirectories
#                                   until nothing more is found.
#   $(filter $(subst *,%,$2),$d) → filters item $d against the patterns in $2.
#                                   Make uses % where the shell uses *, so
#                                   $(subst *,%, ...) converts before calling
#                                   $(filter ...).
#   $(foreach d, LIST, EXPR)     → iterates over each item in LIST, expanding
#                                   EXPR with $d replaced by the current item.
#                                   Concatenates all results with spaces.
# -----------------------------------------------------------------------------
rwildcard = $(foreach d,$(wildcard $(1:=/*)),\
                $(call rwildcard,$d,$2) $(filter $(subst *,%,$2),$d))


# -----------------------------------------------------------------------------
# SOURCE FILES
#
# Collects all .c, .cpp and .s files inside SRC_DIRS, at any subdirectory
# depth, without relying on the shell `find` command.
# -----------------------------------------------------------------------------
SRCS := $(call rwildcard,$(SRC_DIRS),*.c *.cpp *.s)


# -----------------------------------------------------------------------------
# OBJECT AND DEPENDENCY FILES
#
# For each source file, an object file (.o) is created inside BUILD_DIR,
# preserving the original subdirectory structure.
# Example:  src/GameWorld.c  →  build/src/GameWorld.c.o
#
# The substitution operator $(SRCS:%=$(BUILD_DIR)/%.o) applies the pattern
# "BUILD_DIR/ prefix + original value + .o suffix" to every item in SRCS.
#
# The .d files record the dependencies of each .o on the headers (#include)
# used by the corresponding source file. They are generated automatically by
# the -MMD and -MP flags of GCC/Clang during compilation. By including them
# at the end of this Makefile (via -include $(DEPS)), Make learns to recompile
# a .c file whenever any .h it includes changes.
# -----------------------------------------------------------------------------
OBJS := $(SRCS:%=$(BUILD_DIR)/%.o)
DEPS := $(OBJS:.o=.d)


# -----------------------------------------------------------------------------
# INCLUDE DIRECTORIES (headers)
#
# $(call rwildcard, SRC_DIRS, *) returns ALL files under SRC_DIRS, including
# .h files in subdirectories such as src/include/. The * pattern matches any
# filename.
#
# $(dir FILE) extracts the directory portion of each returned path.
# Example: src/include/Foo.h  →  src/include/
#
# $(sort LIST) sorts and removes duplicates (each directory appears once).
#
# $(addprefix -I, LIST) prepends "-I" to each directory. This flag is passed
# to the compiler so it can locate .h files during compilation.
# -----------------------------------------------------------------------------
INC_DIRS  := $(sort $(dir $(call rwildcard,$(SRC_DIRS),*)))
INC_FLAGS := $(addprefix -I,$(INC_DIRS))


# -----------------------------------------------------------------------------
# COMPILER FLAGS
#
# $(INC_FLAGS)           : include paths (-Isrc/ -Isrc/include/ ...)
# -MMD -MP               : generate automatic .d dependency files
# -O1                    : basic optimisation (good balance between build
#                          speed and final binary performance)
# -Wall                  : enable the main set of compiler warnings
# -Wextra                : enable additional warnings beyond -Wall
# -Wno-unused-parameter  : suppress unused-parameter warnings
#                          (common in raylib callbacks and event handlers)
# -pedantic-errors       : treat any non-standard extension as an error
# -std=c99               : follow the ISO C99 standard for .c files
# -std=c++20             : follow the ISO C++20 standard for .cpp files
# -Wno-missing-braces    : suppress false positives with nested initializer
#                          lists in certain GCC versions
# -----------------------------------------------------------------------------
CFLAGS   := $(INC_FLAGS) -MMD -MP -O1 -Wall -Wextra \
             -Wno-unused-parameter -pedantic-errors \
             -std=c99 -Wno-missing-braces

CPPFLAGS := $(INC_FLAGS) -MMD -MP -O1 -Wall -Wextra \
             -Wno-unused-parameter -pedantic-errors \
             -std=c++20 -Wno-missing-braces


# -----------------------------------------------------------------------------
# LINKER FLAGS (platform-dependent)
#
# Linux         : raylib installed system-wide (e.g. via apt/pacman).
#                 Requires OpenGL (GL), pthreads, X11 and other system libs.
#
# macOS         : raylib installed system-wide (e.g. via Homebrew).
#                 Uses native Apple frameworks instead of standalone libs.
#                 -framework OpenGL      : 3D/2D rendering
#                 -framework Cocoa       : windows and macOS events
#                 -framework IOKit       : device input (keyboard, mouse)
#                 -framework CoreVideo   : video synchronisation (VSync)
#
# Windows (both): raylib provided as a static library in lib/libraylib.a.
#                 -L lib/    : add lib/ as a library search directory
#                 -lopengl32 : OpenGL on Windows
#                 -lgdi32    : GDI (Win32 graphics functions)
#                 -lwinmm    : Windows Multimedia (audio)
# -----------------------------------------------------------------------------
ifeq ($(DETECTED_OS), Linux)
    LDFLAGS := -lraylib -lGL -lm -lpthread -ldl -lrt -lX11
else ifeq ($(DETECTED_OS), macOS)
    LDFLAGS := -lraylib -framework OpenGL -framework Cocoa \
               -framework IOKit -framework CoreVideo -lm
else
    # Windows (MSYS2 or native) — raylib from local lib/
    LDFLAGS := -L lib/ -lraylib -lopengl32 -lgdi32 -lwinmm -lm
endif


# -----------------------------------------------------------------------------
# PLATFORM-DEPENDENT SHELL COMMANDS
#
# Command-line tools differ between native Windows cmd.exe and Unix
# environments (Linux, macOS, MSYS2).
#
# MKDIR is a make function called with $(call MKDIR, DIRECTORY):
#   Unix    : mkdir -p <dir>
#               Creates the directory and all required parents.
#               Does not error if the directory already exists (-p).
#   Windows : if not exist "<dir>" mkdir "<dir>"
#               "if not exist" avoids "directory already exists" errors.
#               cmd's mkdir creates parent directories automatically.
#               $(subst /,\,...) converts forward slashes to backslashes
#               (required by cmd.exe).
#
# RM_ALL removes the build directory and all its contents:
#   Unix    : rm -rf build
#   Windows : rmdir /s /q build    (/s = include subdirectories, /q = no prompt)
#             "if exist" check prevents errors when build does not exist yet.
#
# RUN executes the compiled binary:
#   Unix    : ./build/TARGET        (relative Unix path with ./)
#   Windows : build\TARGET.exe      (backslash path for cmd.exe)
# -----------------------------------------------------------------------------
ifeq ($(DETECTED_OS), Windows_Native)
    MKDIR  = if not exist "$(subst /,\,$(1))" mkdir "$(subst /,\,$(1))"
    RM_ALL = if exist $(BUILD_DIR) rmdir /s /q $(BUILD_DIR)
    RUN    = $(subst /,\,$(BUILD_DIR)/$(TARGET_EXEC))
else
    # Linux, macOS and Windows_MSYS2 — all have Unix tools available
    MKDIR  = mkdir -p $(1)
    RM_ALL = rm -rf $(BUILD_DIR)
    RUN    = ./$(BUILD_DIR)/$(TARGET_EXEC)
endif


# =============================================================================
# TARGETS
# =============================================================================

# .PHONY declares targets that do NOT correspond to real files on disk.
# Without this declaration, if a file named "clean" or "run" existed in the
# directory, Make would consider the target already up to date and execute
# nothing. With .PHONY, Make always runs the recipes for these targets.
.PHONY: all compile run clean cleanAndCompile

# Default target (executed with plain `make`): compile then run.
all: compile run

# compile: produces the final binary. Delegates to the link rule below.
compile: $(BUILD_DIR)/$(TARGET_EXEC)

# cleanAndCompile: removes previous build artifacts then recompiles everything.
cleanAndCompile: clean compile


# -----------------------------------------------------------------------------
# FINAL LINK RULE
#
# This rule fires when the final binary needs to be (re)created, i.e. when
# any .o file was modified or the binary does not exist yet.
#
# Automatic variables used:
#   $@  = target name of this rule = the final executable
#         (e.g. build/jogo-plataforma-aula-05  or  build/jogo-plataforma-aula-05.exe)
#   $^  = full list of prerequisites = all .o files listed in $(OBJS)
#
# $(CXX) (C++ compiler) is used for linking even in purely C projects.
# This is safe in mixed C/C++ projects and works equally well for 100% C
# projects. Using $(CC) (C compiler) is also valid as long as no .cpp files
# are present.
# -----------------------------------------------------------------------------
$(BUILD_DIR)/$(TARGET_EXEC): $(OBJS)
	$(call MKDIR,$(BUILD_DIR))
	$(CXX) $^ -o $@ $(LDFLAGS)


# -----------------------------------------------------------------------------
# COMPILATION RULE FOR C FILES
#
# The pattern "$(BUILD_DIR)/%.c.o: %.c" matches any .c file in SRCS and
# defines how to generate the corresponding .o inside BUILD_DIR.
#
# Automatic variables used:
#   $<   = first prerequisite = the .c file being compiled
#   $@   = target name = the .o file being generated
#   $(@D) = target directory (e.g. build/src) — created before compiling
#            to ensure the destination folder exists
# -----------------------------------------------------------------------------
$(BUILD_DIR)/%.c.o: %.c
	$(call MKDIR,$(@D))
	$(CC) $(CFLAGS) -c $< -o $@


# -----------------------------------------------------------------------------
# COMPILATION RULE FOR C++ FILES
# (same logic as the C rule, but uses $(CXX) and $(CPPFLAGS))
# -----------------------------------------------------------------------------
$(BUILD_DIR)/%.cpp.o: %.cpp
	$(call MKDIR,$(@D))
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@


# -----------------------------------------------------------------------------
# clean TARGET: removes the build directory and all generated artifacts
#
# The @ prefix before the command suppresses its display in the terminal.
# Without it, Make would print the command before executing it. With @, only
# the command's output (if any) is shown.
# -----------------------------------------------------------------------------
clean:
	@$(RM_ALL)


# -----------------------------------------------------------------------------
# run TARGET: executes the compiled binary
# -----------------------------------------------------------------------------
run:
	$(RUN)


# -----------------------------------------------------------------------------
# DEPENDENCY FILE INCLUSION (.d files)
#
# The - (hyphen) prefix tells Make to ignore errors if any .d file does not
# exist. This happens normally on the first build, when no .d files have been
# generated yet. After the first build, the .d files exist and are included
# here, making Make aware of header-level dependencies.
# -----------------------------------------------------------------------------
-include $(DEPS)
