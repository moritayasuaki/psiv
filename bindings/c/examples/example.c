/* Public test key only. */
#include <psiv_rust.h>
#include <string.h>
#include <stdio.h>
int main(void) {
    uint8_t key[32]={0},nonce[12]={0},msg[5]={1,2,0,4,5},record[21],opened[5];
    psiv_rs_context *ctx=psiv_rs_new(key,32);
    if(!ctx) return 1;
    ptrdiff_t n=psiv_rs_seal(ctx,nonce,12,NULL,0,msg,5,record,sizeof record);
    if(n!=21){psiv_rs_free(ctx);return 2;}
    n=psiv_rs_open(ctx,nonce,12,NULL,0,record,sizeof record,opened,sizeof opened);
    int pass=n==5 && memcmp(msg,opened,5)==0;
    record[20]^=1;memset(opened,0xa5,sizeof opened);
    pass=pass && psiv_rs_open(ctx,nonce,12,NULL,0,record,sizeof record,opened,sizeof opened)==PSIV_RS_AUTH;
    for(size_t i=0;i<sizeof opened;i++)pass=pass && opened[i]==0xa5;
    psiv_rs_free(ctx);
    if(pass) puts("Rust-backed C library PASS");
    return pass?0:3;
}
