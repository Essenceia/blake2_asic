#include <stdio.h>
#include "blake2s.h" 
#include <string.h> 
#include <assert.h>

// input vector size in bytes
#define IN_SIZE (size_t) 3
#define KEY_SIZE (size_t) 1
// output vector size in bytes
#define OUT_SIZE (size_t) 32

int main(){
	int err;
	size_t i;
	uint8_t d[IN_SIZE], o[OUT_SIZE], k[KEY_SIZE];

	k[0] = 'a';
	
	// generate new test vector
	memset(d, 0, IN_SIZE);
	d[0] = 'a';
	d[1] = 'b';
	d[2] = 'c';	

	printf("inlen: %ld, in[%ld:0]: 0x", IN_SIZE, IN_SIZE*8-1);
	for(i=IN_SIZE;i--;){
		printf("%02X",d[i]);
	}
	printf("\n");
	
	// int blake2s(void *out, size_t outlen, const void *key, size_t keylen, const void *in, size_t inlen)
	err = blake2s(&o, OUT_SIZE, &k, KEY_SIZE, &d, IN_SIZE);	
	//err = blake2s(&o, OUT_SIZE, &k, 0, &d, IN_SIZE);	
	assert(err == 0);
	
	printf("outlen: %ld, out[%ld:0]: 0x", OUT_SIZE, OUT_SIZE*8-1);
	for( i =OUT_SIZE;i-->0;){
		printf("%02X",o[i]);
	};
	printf("\n");
	
	return 0;
}
