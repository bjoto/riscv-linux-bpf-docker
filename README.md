# RISC-V BPF Docker kselftest builder/runner

0. Build container (once)
```
docker build . -t bpf-ci
```

1. Enter Linux root
```
# e.g.
cd src/linux
```

2. Run tests
```
docker run -it --volume $PWD:/build/my-linux \
               --volume /path/to/docker_ccache:/build/ccache \
			   bpf-ci bash -l run.sh self-bpf-all
```

## Valid test strings
```
        "self-all") # excluding bpf and net
        "self-net")
        "self-bpf-all") # all bpf tests
        "self-bpf-test_progs")
        "self-bpf-test_progs_no_alu32")
        "self-bpf-test_progs_cpuv4")
        "self-bpf-test_maps")
        "self-bpf-test_verifier")

```
