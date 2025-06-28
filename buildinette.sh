#!/bin/bash
# buildinette - A project skeleton generator for School 42 projects.
#
# Usage:
#   buildinette -name="<project_name>" [-libft="<git@libft_repo>"] [-mlx] [-link="<absolute|relative>"] [-git="<git@project_repo>"]
#
# Options:
#   -name    : (Mandatory) Name of the project.
#   -libft   : (Optional) Git URL for the libft repository.
#   -mlx     : (Optional) Enable MinilibX support. This will clone the repository
#             from https://github.com/42paris/minilibx-linux.git into the project.
#             The script automatically sets linker flags based on your OS.
#   -link    : (Optional) "absolute" or "relative". In "relative" mode the Makefile adds
#             "-Iincludes" so that your source files include headers with a relative path.
#             In "absolute" mode no include flag is added (expecting absolute #include paths).
#   -git     : (Optional) Git remote for the project. Initializes a git repo and sets the remote.
#
# Requirements:
#   - git must be installed.
#   - For –mlx: On Linux you must have gcc, make, X11 development packages (xorg, libxext-dev, libbsd-dev).
#             On macOS, you should have XQuartz installed.
#
# This script creates the following project structure:
#
# <project_name>/
# ├── Makefile         # Generated Makefile with conditional libft and mlx commands.
# ├── includes/
# │     └── <project_name>.h
# ├── srcs/
# │     └── <project_name>.c
# ├── [libft/]         # (Optional) Cloned libft repository if -libft is provided.
# └── [mlx/]           # (Optional) Cloned minilibX repository if -mlx is provided.
#

#
#
INSTALL_PATH="/usr/local/bin/buildinette"
VERSION="1.0.0"
REPO_URL="https://github.com/maxime-c16/buildinette.git"

PROJECT_NAME="default_project" # Default project name, can be overridden by -name
PROJECT_ROOT="." # Default project root, current directory

# Function to check for updates
check_for_updates() {
    # Fetch the latest version of the script from the remote repository
    LATEST_VERSION=$(curl -s "$REPO_URL" | grep -m 1 "VERSION=" | cut -d'=' -f2 | tr -d '"')

    if [ -z "$LATEST_VERSION" ]; then
        echo "Could not fetch the latest version."
        return
    fi

    # Compare the version of the installed script with the latest version
    if [ "$VERSION" != "$LATEST_VERSION" ]; then
        echo "A new version of buildinette is available: $LATEST_VERSION"
        read -p "Do you want to update? (y/n) " -r
        echo
        if [[ ${REPLY:0:1} =~ ^[Yy]$ ]]; then
            # Download the new script and replace the old one
            sudo curl -s -o "$INSTALL_PATH" "$REPO_URL" && sudo chmod +x "$INSTALL_PATH"
            echo "buildinette has been updated to version $LATEST_VERSION"
        fi
    else
        echo "buildinette is up to date."
    fi
}

# If the script is run with the --update argument, check for updates and exit
if [ "$1" == "--update" ]; then
    check_for_updates
    exit 0
fi

if [ ! -f "$INSTALL_PATH" ]; then
    read -p "buildinette is not installed system-wide. Do you want to install it to $INSTALL_PATH? (y/n) " -r
    echo
    if [[ ${REPLY:0:1} =~ ^[Yy]$ ]]; then
        echo "Installing buildinette to $INSTALL_PATH..."
        sudo cp "$0" "$INSTALL_PATH" && sudo chmod +x "$INSTALL_PATH"
        if [ $? -eq 0 ]; then
            echo "buildinette installed successfully. You can now run 'buildinette' from anywhere."
        else
            echo "Error: Failed to install buildinette."
        fi
    fi
fi

# Automatically check for updates in the background
if [ -f "$INSTALL_PATH" ]; then
    (check_for_updates >/dev/null 2>&1) &
fi

CONFIG_FILE="$HOME/.config/buildinette.conf"

# Parse command-line arguments
while getopts ":n:l:m:L:g:h" opt; do
	case $opt in
		n)
			PROJECT_NAME="$OPTARG"
			;;
		l)
			LIBFT_REPO="$OPTARG"
			;;
		m)
			MLX_OPTION="yes"
			;;
		L)
			LINK_OPTION="$OPTARG"
			;;
		g)
			PROJECT_GIT="$OPTARG"
			;;
		h)
			usage
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			usage
			;;
		:)
			echo "Option -$OPTARG requires an argument." >&2
			usage
			;;
	esac
done
shift $((OPTIND-1))

# Function to display usage information
usage() {
	echo "Usage: $0 [-h|--help]"
	exit 1
}

# Function to generate project files for a given path and name
generate_single_project() {
	local target_dir="$1"
	local file_name="$2" # This will be the name used in .c, .h, Makefile

	mkdir -p "$target_dir/src" "$target_dir/include"

	# Generate source & header files
	cat > "$target_dir/src/${file_name}.${SRC_EXT}" <<EOF
#include "$(if [ "$LINK_OPTION" = "relative" ]; then echo "${file_name}.${HEADER_EXT}"; else echo "../include/${file_name}.${HEADER_EXT}"; fi)"

int main(int ac, char **av)
{
	return (0);
}
EOF

	cat > "$target_dir/include/${file_name}.${HEADER_EXT}" <<EOF
#ifndef $(echo "${file_name}" | tr '[:lower:]' '[:upper:]')_HPP

# define $(echo "${file_name}" | tr '[:lower:]' '[:upper:]')_HPP
$( [[ -n "$MLX_OPTION" ]] && echo '
# include "../mlx/mlx.h"

')
// Add your declarations here

#endif
EOF

	# Generate Makefile
	cat > "$target_dir/Makefile" <<EOF
FILES	=	${file_name}.${SRC_EXT}
SRC_DIR	=	src
SRCS	=	\$(addprefix \$(SRC_DIR)/, \$(FILES))
OBJ_DIR	=	.objs
OBJS	=	\$(addprefix \$(OBJ_DIR)/, \$(FILES:.${SRC_EXT}=.o))
HEADER_DIR	=	include
HEADERS	=	\$(addprefix \$(HEADER_DIR)/, ${file_name}.${HEADER_EXT})

NAME	=	${file_name}
CC		=	${CC}
CFLAGS	=	${CFLAGS} $( [[ "$LINK_OPTION" == "relative" ]] && echo "-Iinclude" )
DEBUG	=	-fsanitize=address
RM		=	/bin/rm -rf
LDFLAGS	=	${LDFLAGS}

all:		\$(NAME)

\$(NAME):	\$(OBJS)
EOF

	# Adjust Makefile for libft and mlx paths
	local libft_make_path="libft"
	local mlx_make_path="mlx"
	if [[ "$target_dir" != "." ]]; then # If it's not the root project
		libft_make_path="../libft"
		mlx_make_path="../mlx"
	fi

	[[ -n "$LIBFT_REPO" ]] && echo "	\$(MAKE) -C $libft_make_path" >> "$target_dir/Makefile"
	[[ -n "$MLX_OPTION" ]] && echo "	\$(MAKE) -C $mlx_make_path" >> "$target_dir/Makefile"

	cat >> "$target_dir/Makefile" <<EOF
	\$(CC) \$(CFLAGS) \$(OBJS) \$(LDFLAGS) -o \$(NAME)

\$(OBJ_DIR)/%.o:	\$(SRC_DIR)/%.${SRC_EXT} \$(HEADERS)
	@mkdir -p \$(OBJ_DIR)
	\$(CC) \$(CFLAGS) -c \$< -o \$@

debug:		\$(OBJS)
EOF

	[[ -n "$LIBFT_REPO" ]] && echo "	\$(MAKE) -C $libft_make_path" >> "$target_dir/Makefile"
	[[ -n "$MLX_OPTION" ]] && echo "	\$(MAKE) -C $mlx_make_path" >> "$target_dir/Makefile"

	cat >> "$target_dir/Makefile" <<EOF
	\$(CC) \$(CFLAGS) \$(DEBUG) \$(OBJS) \$(LDFLAGS) -o \$(NAME)

clean:
EOF

	[[ -n "$LIBFT_REPO" ]] && echo "	\$(MAKE) -C $libft_make_path clean" >> "$target_dir/Makefile"
	[[ -n "$MLX_OPTION" ]] && echo "	\$(MAKE) -C $mlx_make_path clean" >> "$target_dir/Makefile"

	cat >> "$target_dir/Makefile" <<EOF
	\$(RM) \$(OBJ_DIR)

fclean: clean
EOF

	[[ -n "$LIBFT_REPO" ]] && echo "	\$(MAKE) -C $libft_make_path fclean" >> "$target_dir/Makefile"

	cat >> "$target_dir/Makefile" <<EOF
	\$(RM) \$(NAME)

re:			fclean all

.PHONY:		all clean fclean re
EOF
}

# Load configuration if available
if [[ -f "$CONFIG_FILE" ]]; then
	source "$CONFIG_FILE"
fi

# Initialize PROJECTS_TO_GENERATE array
PROJECTS_TO_GENERATE=()

# If PROJECT_NAME is not set by command line, prompt for it
if [[ -z "$PROJECT_NAME" ]]; then
	if [[ -t 0 ]]; then
		read -p "Enter project name: " PROJECT_NAME
	else
		read PROJECT_NAME
	fi
	if [[ -z "$PROJECT_NAME" ]]; then
		echo "Project name cannot be empty. Exiting."
		exit 1
	fi
fi


# Main project always added first
PROJECTS_TO_GENERATE+=(".:$PROJECT_NAME")

# Process subprojects if any
if [[ -t 0 ]]; then # Check if stdin is a TTY
	read -p "Do you want to create subprojects? (y/n): " -r
	echo
else
	read REPLY
fi

if [[ $REPLY =~ ^[Yy]$ ]]; then
	if [[ -t 0 ]]; then
		read -p "Enter the parent folder name for subprojects (e.g., 'my_project'): " PARENT_FOLDER_NAME
	else
		read PARENT_FOLDER_NAME
	fi
	if [[ -z "$PARENT_FOLDER_NAME" ]]; then
		echo "Parent folder name cannot be empty. Using '$PROJECT_NAME' as default."
		PARENT_FOLDER_NAME="$PROJECT_NAME"
	fi

	if [[ -t 0 ]]; then
		read -p "Enter subproject names (space-separated, leave empty to finish): " SUB_NAMES_INPUT
	else
		read SUB_NAMES_INPUT
	fi
	for SUB_NAME_INPUT in $SUB_NAMES_INPUT; do
		PROJECTS_TO_GENERATE+=("$PARENT_FOLDER_NAME/$SUB_NAME_INPUT:$SUB_NAME_INPUT")
	done
fi

# Prompt for libft
if [[ -t 0 ]]; then
	read -p "Do you want to include libft? (y/n): " -r
	echo
else
	read REPLY
fi

if [[ $REPLY =~ ^[Yy]$ ]]; then
	if [[ -t 0 ]]; then
		read -p "Enter libft repository URL (e.g., https://github.com/42School/libft.git): " LIBFT_REPO
	else
		read LIBFT_REPO
	fi
	# Store in config file
	grep -q "^LIBFT_DEFAULT=" "$CONFIG_FILE" && \
	sed -i '' "s|^LIBFT_DEFAULT=.*|LIBFT_DEFAULT=\"$LIBFT_REPO\"|" "$CONFIG_FILE" || \
	echo "LIBFT_DEFAULT=\"$LIBFT_REPO\"" >> "$CONFIG_FILE"
fi

# Prompt for mlx
if [[ -t 0 ]]; then
	read -p "Do you want to include MinilibX? (y/n): " -r
	echo
else
	read REPLY
fi

if [[ $REPLY =~ ^[Yy]$ ]]; then
	MLX_OPTION="yes"
fi

# Prompt for link option
if [[ -t 0 ]]; then
	read -p "Choose linking mode (absolute/relative, default absolute): " LINK_OPTION_INPUT
	LINK_OPTION=${LINK_OPTION_INPUT:-absolute}
else
	read LINK_OPTION_INPUT
	LINK_OPTION=${LINK_OPTION_INPUT:-absolute}
fi

# Prompt for git remote
if [[ -t 0 ]]; then
	read -p "Do you want to initialize a Git repository and set a remote? (y/n): " -r
	echo
else
	read REPLY
fi

if [[ $REPLY =~ ^[Yy]$ ]]; then
	if [[ -t 0 ]]; then
		read -p "Enter Git remote URL: " PROJECT_GIT
	else
		read PROJECT_GIT
	fi
fi

# Prompt for C++
if [[ -t 0 ]]; then
	read -p "Do you want C++ support? (y/n): " -r
	echo
else
	read REPLY
fi

if [[ $REPLY =~ ^[Yy]$ ]]; then
	CPP_OPTION="yes"
fi

# Prompt for Intra remote
if [[ -t 0 ]]; then
	read -p "Do you want to add an Intranet git remote (vogsphere)? (y/n): " -r
	echo
else
	read REPLY
fi

if [[ $REPLY =~ ^[Yy]$ ]]; then
	INTRA_OPTION="yes"
fi

# Set default values for compilation based on C++ option
if [[ -n "$CPP_OPTION" ]]; then
	SRC_EXT="cpp"
	HEADER_EXT="hpp"
	CC="g++"
	CFLAGS="-Wall -Wextra -Werror -std=c++98"
	LDFLAGS=""
else
	SRC_EXT="c"
	HEADER_EXT="h"
	CC="gcc"
	CFLAGS="-Wall -Wextra -Werror"
	LDFLAGS=""
fi

echo "DEBUG: PROJECTS_TO_GENERATE array before loop: ${PROJECTS_TO_GENERATE[@]}"

# Loop through projects to generate
echo "DEBUG: PROJECTS_TO_GENERATE array: ${PROJECTS_TO_GENERATE[@]}"
for project_entry in "${PROJECTS_TO_GENERATE[@]}"; do
	IFS=":" read -r target_path file_name <<< "$project_entry"
	echo "Generating project: $file_name in $target_path"
	generate_single_project "$target_path" "$file_name"

	# Clone libft if specified
	if [[ -n "$LIBFT_REPO" ]]; then
		echo "Cloning libft from $LIBFT_REPO into $target_path/libft"
		git clone "$LIBFT_REPO" "$target_path/libft"
	fi

	# Clone MinilibX if specified
	if [[ -n "$MLX_OPTION" ]]; then
		echo "Cloning MinilibX into $target_path/mlx"
		git clone https://github.com/42paris/minilibx-linux.git "$target_path/mlx"
	fi

	# Initialize Git repo and set remote if specified
	if [[ -n "$PROJECT_GIT" ]]; then
		echo "Initializing Git repository and setting remote for $target_path"
		(cd "$target_path" && git init && git remote add origin "$PROJECT_GIT")
	fi

	# Add Intra remote if specified
	if [[ -n "$INTRA_OPTION" ]]; then
		echo "Adding Intra remote for $target_path"
		(cd "$target_path" && git remote add vogsphere git@vogsphere.42.fr:intra/$(basename "$target_path"))
	fi
done









