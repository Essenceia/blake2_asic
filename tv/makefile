
ifndef debug
#debug :=
endif

FLAGS = -Wall -Wextra -Wconversion -Wshadow -Wundef -fno-common  -Wno-unused-parameter -Wno-type-limits
CC = cc $(if $(debug),-DDEBUG -g)
LD = cc

run: blake2 
	./blake2

blake2 : main.o blake2s.o
	$(LD) -o blake2 -g main.o blake2s.o 

main.o : main.c
	$(CC) -c main.c $(FLAGS)

blake2s.o : blake2s.c blake2s.h
	$(CC) -c blake2s.c $(FLAGS)

clean :
	rm -f *.o
	rm -f vgcore.* 
