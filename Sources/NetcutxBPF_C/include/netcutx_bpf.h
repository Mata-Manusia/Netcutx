#ifndef NETCUTX_BPF_H
#define NETCUTX_BPF_H

#include <stdint.h>
#include <stddef.h>
#include <sys/types.h>

typedef struct netcutx_bpf_ctx netcutx_bpf_ctx_t;

netcutx_bpf_ctx_t* netcutx_bpf_open(const char* interface_name);

ssize_t netcutx_bpf_send(netcutx_bpf_ctx_t* ctx, const uint8_t* frame, size_t len);

ssize_t netcutx_bpf_recv(netcutx_bpf_ctx_t* ctx, uint8_t* buf, size_t cap, int timeout_ms);

void netcutx_bpf_close(netcutx_bpf_ctx_t* ctx);

const char* netcutx_bpf_error(netcutx_bpf_ctx_t* ctx);

void netcutx_init_signal(void);
int netcutx_should_stop(void);

#endif
