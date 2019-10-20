# makefile
# SHA1 program
# Connor Horne
# ECE 565

# directories
SRC=src/
BLD=build/

# compiler
# change this compiler for non hpc applications
CC = g++-8
#FLG = -Wall -Wextra -Werror
FLG = -Wall -Wextra -Werror -O3
OPT =  
OBJ = $(BLD)sha.o 
LIB = -L/usr/lib/x86_64-linux-gnu -lcudart -lcuda

# nvidia compiler
NCC = nvcc
NFLG= -maxrregcount 32
#NFLG = -Xptxas=-v,-abi=no -O3
#NFLG = -Xptxas=-v,-abi=no  -maxrregcount 32
#NFLG = -Xptxas=-v,-abi=no  -maxrregcount 32 -O3
#NFLG =
NOPT = 
NOBJ =
NLIB = -L/usr/lib/cuda/lib64 -lcudart -lcuda

# program name
PRG = sha

# build
all: dir $(BLD)$(PRG)

dir:
	mkdir -p $(BLD)

$(BLD)$(PRG): $(OBJ) $(SRC)main.cpp
	$(CC) $(FLG) $(LIB) $^ -o $@

$(BLD)sha.o: $(SRC)sha.cu
	$(NCC) $(NFLG) $(NLIB) -c $^ -o $@

# alt cmds
clean:
	rm -r $(BLD) 
