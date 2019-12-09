.PHONY: all clean

all: hello

clean:
	$(RM) -f *.o
	$(RM) -f hello

hello: hello.c
	$(CC) -o $@ $<
