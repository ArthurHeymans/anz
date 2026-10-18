CC ?= cc
CFLAGS ?= -O2 -Wall -Wextra
SRC = anz.c fhl/fhl.c
DEP = $(SRC) anz.h fhl/fhl.h

all: anz

anz: $(DEP)
	$(CC) $(CFLAGS) -DFHL_LIB -pthread -o $@ $(SRC) -lm

anz-asan: $(DEP)
	$(CC) -O1 -g -fsanitize=address,undefined -DFHL_LIB -pthread -o $@ $(SRC) -lm

anz-scalar-asan: $(DEP)
	$(CC) -O1 -g -fsanitize=address,undefined -DFHL_LIB -DANZ_SCALAR -pthread -o $@ $(SRC) -lm

test: anz-asan anz-scalar-asan
	./tests/run.sh ./anz-asan
	./tests/run.sh ./anz-scalar-asan

clean:
	rm -f anz anz-asan anz-scalar-asan

.PHONY: all test clean
