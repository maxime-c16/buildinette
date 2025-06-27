FILES    =    default_project.cpp
SRC_DIR    =    src
SRCS    =    $(addprefix $(SRC_DIR)/, $(FILES))
OBJ_DIR    =    .objs
OBJS    =    $(addprefix $(OBJ_DIR)/, $(FILES:.cpp=.o))
HEADER_DIR    =    include
HEADERS    =    $(addprefix $(HEADER_DIR)/, default_project.hpp)

NAME    =    default_project
CC        =    g++
CFLAGS    =    -Wall -Wextra -Werror -std=c++98 
DEBUG    =    -fsanitize=address
RM        =    /bin/rm -rf
LDFLAGS    =    

all:        $(NAME)

$(NAME):    $(OBJS) $(HEADERS)
        $(CC) $(CFLAGS) $(OBJS) $(LDFLAGS) -o $(NAME)

$(OBJ_DIR)/%.o:    $(SRC_DIR)/%.cpp
        @mkdir -p $(OBJ_DIR)
        $(CC) $(CFLAGS) -c $< -o $@

debug:        $(OBJS)
        $(CC) $(CFLAGS) $(DEBUG) $(OBJS) $(LDFLAGS) -o $(NAME)

clean:
        $(RM) $(OBJ_DIR)

fclean: clean
        $(RM) $(NAME)

re:            fclean all

.PHONY:        all clean fclean re
