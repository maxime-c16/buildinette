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

CONFIG_FILE="$HOME/.config/buildinette.conf"

# Function to display usage information
usage() {
	echo "Usage: $0 -n=\"<project_name>\" [-l[=\"<git@libft>\"]|--libft[=\"<git@libft>\"]] [-m|--mlx] [-L=\"absolute|relative\"] [-g=\"<git@project>\"] [-c=\"<compiler>\"] [-h|--help]"
	exit 1
}

# Load configuration if available
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Parse command-line options
for arg in "$@"; do
	case $arg in
		-n=*|--name=*)
			PROJECT_NAME="${arg#*=}"
			shift
			;;
		--libft-force=*)
			LIBFT_REPO="${arg#*=}"
			sed -i "s/^LIBFT_DEFAULT=.*$/LIBFT_DEFAULT=\"$LIBFT_REPO\"/" "$CONFIG_FILE"
			shift
			;;
		-l=*|--libft=*)
			if [[ -z "$LIBFT_DEFAULT" ]]; then
				LIBFT_REPO="${arg#*=}"
				echo "LIBFT_DEFAULT=\"$LIBFT_REPO\"" >> "$CONFIG_FILE"
				echo "✅ LIBFT_DEFAULT configured in $CONFIG_FILE."
			else
				echo "Error: LIBFT_DEFAULT is already configured in $CONFIG_FILE."
				echo '       Use --libft-force="<git@libft_repo>" option to override the configuration.'
				exit 1
			fi
			shift
			;;
		-l|--libft)
			if [[ -z "$LIBFT_DEFAULT" ]]; then
				echo "Error: -l option requires configuring LIBFT_DEFAULT in $CONFIG_FILE."
				echo '       Provide the repository URL with -l="<git@libft_repo>" for configuration.'
				usage
			else
				LIBFT_REPO="$LIBFT_DEFAULT"
			fi
			shift
			;;
		-m|--mlx)
			MLX_OPTION="yes"
			shift
			;;
		-L=*|--link=*)
			LINK_OPTION="${arg#*=}"
			shift
			;;
		-g=*|--git=*)
			PROJECT_GIT="${arg#*=}"
			shift
			;;
		-c=*|--cc=*)
			CC="${arg#*=}"
			shift
			;;
		-h|--help)
			usage
			;;
		*)
			echo "Unknown option: $arg"
			usage
			;;
	esac
done

# Check required option
if [[ -z "$PROJECT_NAME" ]]; then
	echo "Error: -name option is required."
	usage
fi

# Set defaults
LINK_OPTION=${LINK_OPTION:-"absolute"}
CC=${CC:-"gcc"}
LDFLAGS=""

# Detect OS type
OS_TYPE=$(uname)
MLX_LINK_FLAGS=$([[ "$OS_TYPE" == "Darwin" ]] && echo "-Lmlx -lmlx -framework OpenGL -framework AppKit" || echo "-Lmlx -lmlx -lX11 -lXext -lbsd")

# Create project directories
mkdir -p "$PROJECT_NAME/srcs" "$PROJECT_NAME/includes"

# Generate source & header files
cat > "$PROJECT_NAME/srcs/${PROJECT_NAME}.c" <<EOF
#include "$(if [ "$LINK_OPTION" = "relative" ]; then echo "${PROJECT_NAME}.h"; else echo "../includes/${PROJECT_NAME}.h"; fi)"

int	main(int ac, char **av)
{
	return (0);
}
EOF

cat > "$PROJECT_NAME/includes/${PROJECT_NAME}.h" <<EOF
#ifndef $(echo "${PROJECT_NAME}" | tr '[:lower:]' '[:upper:]')_H

# define $(echo "${PROJECT_NAME}" | tr '[:lower:]' '[:upper:]')_H
$( [[ -n "$MLX_OPTION" ]] && echo '
# include "../mlx/mlx.h"

')
// Add your declarations here

#endif
EOF

# Handle libft linking
if [[ -n "$LIBFT_REPO" ]]; then
	LDFLAGS+=" -Llibft -lft"
fi

# Handle mlx linking
if [[ -n "$MLX_OPTION" ]]; then
	LDFLAGS+=" $MLX_LINK_FLAGS"
fi

# Generate Makefile
cat > "$PROJECT_NAME/Makefile" <<EOF
FILES	=	${PROJECT_NAME}.c
SRC_DIR	=	srcs
SRCS	=	\$(addprefix \$(SRC_DIR)/, \$(FILES))
OBJ_DIR	=	.objs
OBJS	=	\$(addprefix \$(OBJ_DIR)/, \$(FILES:.c=.o))

NAME	=	${PROJECT_NAME}
CC		=	${CC}
CFLAGS	=	-g3 $( [[ "$LINK_OPTION" == "relative" ]] && echo "-Iincludes" )
DEBUG	=	-fsanitize=address
RM		=	/bin/rm -rf
LDFLAGS	=	${LDFLAGS}

all:		\$(NAME)

\$(NAME):	\$(OBJS)
EOF

[[ -n "$LIBFT_REPO" ]] && echo '		$(MAKE) -C libft' >> "$PROJECT_NAME/Makefile"
[[ -n "$MLX_OPTION" ]] && echo '		$(MAKE) -C mlx' >> "$PROJECT_NAME/Makefile"

cat >> "$PROJECT_NAME/Makefile" <<EOF
		\$(CC) \$(CFLAGS) \$(OBJS) \$(LDFLAGS) -o \$(NAME)

\$(OBJ_DIR)/%.o:	\$(SRC_DIR)/%.c
		@mkdir -p \$(OBJ_DIR)
		\$(CC) \$(CFLAGS) -c \$< -o \$@

debug:		\$(OBJS)
EOF

[[ -n "$LIBFT_REPO" ]] && echo '		$(MAKE) -C libft' >> "$PROJECT_NAME/Makefile"
[[ -n "$MLX_OPTION" ]] && echo '		$(MAKE) -C mlx' >> "$PROJECT_NAME/Makefile"

cat >> "$PROJECT_NAME/Makefile" <<EOF
		\$(CC) \$(CFLAGS) \$(DEBUG) \$(OBJS) \$(LDFLAGS) -o \$(NAME)

clean:
EOF

[[ -n "$LIBFT_REPO" ]] && echo '		$(MAKE) -C libft clean' >> "$PROJECT_NAME/Makefile"
[[ -n "$MLX_OPTION" ]] && echo '		$(MAKE) -C mlx clean' >> "$PROJECT_NAME/Makefile"

cat >> "$PROJECT_NAME/Makefile" <<EOF
		\$(RM) \$(OBJ_DIR)

fclean: clean
EOF

[[ -n "$LIBFT_REPO" ]] && echo '		$(MAKE) -C libft fclean' >> "$PROJECT_NAME/Makefile"

cat >> "$PROJECT_NAME/Makefile" <<EOF
		\$(RM) \$(NAME)

re:			fclean all

.PHONY:		all clean fclean re
EOF

# Clone libft if required
if [[ -n "$LIBFT_REPO" ]]; then
	mkdir -p "$PROJECT_NAME/libft"
	echo "Cloning libft repository..."
	git clone "$LIBFT_REPO" "$PROJECT_NAME/libft"
	rm -rf "$PROJECT_NAME/libft/.git"
fi

# Clone mlx if required
if [[ -n "$MLX_OPTION" ]]; then
	mkdir -p "$PROJECT_NAME/mlx"
	echo "Cloning minilibX repository..."
	git clone https://github.com/42paris/minilibx-linux.git "$PROJECT_NAME/mlx"
	[[ "$OS_TYPE" == "Darwin" ]] && echo "ℹ️ macOS users should install XQuartz for MinilibX support."
	rm -rf "$PROJECT_NAME/mlx/.git"
fi

# Initialize git if -git option is used
if [[ -n "$PROJECT_GIT" ]]; then
	(cd "$PROJECT_NAME" && git init && git remote add origin "$PROJECT_GIT")
fi

# Summary output
echo "✅ Project '$PROJECT_NAME' structure created successfully."
[[ -n "$LIBFT_REPO" ]] && echo "🔗 libft cloned from $LIBFT_REPO."
[[ -n "$PROJECT_GIT" ]] && echo "🌍 Git repository initialized with remote $PROJECT_GIT. Push using git push --set-upstream origin master"
[[ -n "$MLX_OPTION" ]] && echo "🖥️ MinilibX support enabled."

exit 0
