#!/bin/bash
# buildinette - A project skeleton generator for School 42 projects.
#
# Usage:
#   buildinette -name="<project_name>" [-libft="<git@libft_repo>"] [-link="<absolute|relative>"] [-git="<git@project_repo>"]
#
# This script creates the following layout:
#
# <project_name>/
# ├── Makefile         # Generated as per provided example (using srcs, .objs, linking libft if specified)
# ├── includes/
# │     └── <project_name>.h
# └── srcs/
#       └── <project_name>.c
#
# If the -link option is "absolute", the Makefile will compile without adding any include flags,
# meaning your .c files must #include headers via an absolute path.
# If "relative", the Makefile will compile with -Iincludes.
#
# Additionally, if -libft is provided the libft repo will be cloned into a libft/ folder,
# and if -git is provided, a git repository will be initialized with that remote.

# Function to display usage
usage() {
	echo "Usage: $0 -name=\"<project_name>\" [-libft=\"<git@libft_repo>\"] [-link=\"absolute|relative\"] [-git=\"<git@project_repo>\"]"
	exit 1
}

# Parse options
for arg in "$@"; do
	case $arg in
		-name=*)
			PROJECT_NAME="${arg#*=}"
			shift
			;;
		-libft=*)
			LIBFT_REPO="${arg#*=}"
			shift
			;;
		-link=*)
			LINK_OPTION="${arg#*=}"
			shift
			;;
		-git=*)
			PROJECT_GIT="${arg#*=}"
			shift
			;;
		-cc=*)
			CC="${arg#*=}"
			shift
			;;
		-h | --help)
			usage
			;;
		*)
			echo "Unknown option: $arg"
			usage
			;;
	esac
done

# Check mandatory -name option
if [[ -z "$PROJECT_NAME" ]]; then
	echo "Error: -name option is required."
	usage
fi

# Default link mode is relative if not specified
if [[ -z "$LINK_OPTION" ]]; then
	LINK_OPTION="absolute"
fi

# Default compiler is gcc if not specified
if [[ -z "$CC" ]]; then
	CC="gcc"
fi

# Create project directory structure
mkdir -p "$PROJECT_NAME/srcs"
mkdir -p "$PROJECT_NAME/includes"

# Create a basic source file and header file
SOURCE_FILE="$PROJECT_NAME/srcs/${PROJECT_NAME}.c"
HEADER_FILE="$PROJECT_NAME/includes/${PROJECT_NAME}.h"

# Create an example source file (with a simple main function)
cat > "$SOURCE_FILE" <<EOF
#include "$(if [ "$LINK_OPTION" = "relative" ]; then echo "${PROJECT_NAME}.h"; else echo "../includes/${PROJECT_NAME}.h"; fi)"

int	main(int ac, char **av)
{
	return 0;
}
EOF

# Create a simple header file
cat > "$HEADER_FILE" <<EOF
#ifndef $(echo "${PROJECT_NAME}" | tr '[:lower:]' '[:upper:]')_H

# define $(echo "${PROJECT_NAME}" | tr '[:lower:]' '[:upper:]')_H

// Add your declarations here

#endif
EOF

# Decide on LDFLAGS: if libft is provided, then link with it.
if [[ -n "$LIBFT_REPO" ]]; then
	LDFLAGS="-Llibft -lft"
else
	LDFLAGS=""
fi

# Set include flag for "relative" mode; if absolute, do not add any
if [[ "$LINK_OPTION" == "relative" ]]; then
	INCLUDE_FLAG="-Iincludes"
else
	INCLUDE_FLAG=""
fi

# Generate the Makefile
# Append project-specific variables to the Makefile
cat > "$PROJECT_NAME/Makefile" <<EOF
FILES	=	${PROJECT_NAME}.c

SRC_DIR	=	srcs
SRCS	=	\$(addprefix \$(SRC_DIR)/, \$(FILES))

OBJ_DIR	=	.objs
OBJS	=	\$(addprefix \$(OBJ_DIR)/, \$(FILES:.c=.o))

NAME	=	${PROJECT_NAME}
CC		=	${CC}
CFLAGS	=	-g3 ${INCLUDE_FLAG}
DEBUG	=	-fsanitize=address
RM		=	/bin/rm -rf
LDFLAGS	=	${LDFLAGS}

all:		\$(NAME)

EOF

# Append build commands to the Makefile
{
    # Start the main target
    echo '$(NAME):	$(OBJS)'
    if [[ -n "$LIBFT_REPO" ]]; then
        echo '		$(MAKE) -C libft'
    fi
    echo '		$(CC) $(CFLAGS) $(OBJS) $(LDFLAGS) -o $(NAME)'
    echo ''
    echo '$(OBJ_DIR)/%.o:	$(SRC_DIR)/%.c'
    echo '		@mkdir -p $(OBJ_DIR)'
    echo '		$(CC) $(CFLAGS) -c $< -o $@'
    echo ''
    echo 'debug:		$(OBJS)'
    if [[ -n "$LIBFT_REPO" ]]; then
        echo '		$(MAKE) -C libft'
    fi
    echo '		$(CC) $(CFLAGS) $(DEBUG) $(OBJS) $(LDFLAGS) -o $(NAME)'
    echo ''
    echo 'clean:'
    if [[ -n "$LIBFT_REPO" ]]; then
        echo '		$(MAKE) -C libft clean'
    fi
    echo '		$(RM) $(OBJ_DIR)'
    echo ''
    echo 'fclean:		clean'
    if [[ -n "$LIBFT_REPO" ]]; then
        echo '		$(MAKE) -C libft fclean'
    fi
    echo '		$(RM) $(NAME)'
    echo ''
    echo 're:			fclean all'
    echo ''
    echo '.PHONY:		all clean fclean re'
} >> "$PROJECT_NAME/Makefile"


# If the -libft option is provided, clone the libft repository
if [[ -n "$LIBFT_REPO" ]]; then
	mkdir -p "$PROJECT_NAME/libft"
	echo "Cloning libft repository..."
	git clone "$LIBFT_REPO" "$PROJECT_NAME/libft"
fi

# If the -git option is provided, initialize a git repository and add remote
if [[ -n "$PROJECT_GIT" ]]; then
	(cd "$PROJECT_NAME" && git init && git remote add origin "$PROJECT_GIT")
fi

echo "Project '$PROJECT_NAME' structure created successfully."
[[ -n "$LIBFT_REPO" ]] && echo "libft cloned from $LIBFT_REPO."
[[ -n "$PROJECT_GIT" ]] && echo "Git repository initialized with remote $PROJECT_GIT."

# End of buildinette.sh
exit 0
