#include <stdio.h>

int g;

#if 1
/* This is without any meaning, but it can be compacted. */
#define X(x, y) g + (x^(g-1+y)) - (g+1-y) * (x^(3 << y)) + ((g|x)+y) - ((g&x)-y);
#else
#define X(x, y) k
#endif

int hex(int x)
{
	printf("haha %x\n", x);
	int k=g;
	while (x-- > 0) k+= x ^ k;
	return X(x,k);
}

int dec(int x)
{
	printf("haha %d\n", x);
	int k=g;
	while (x-- > 0) k+= x ^ k;
	return X(x,k);
}

int flt(int x)
{
	printf("haha %f\n", (double)x);
	int k=g;
	while (x-- > 0) k+= x ^ k;
	return X(x,k);
}

int oct(int x)
{
	printf("haha %o\n", x);
	int k=g;
	while (x-- > 0) k+= x ^ k;
	return X(x,k);
}

int main(int argc, char *args[])
{
	g=argc;
	dec(argc);
	hex(argc);
	flt(argc);
	oct(argc);
	return 0;
}
