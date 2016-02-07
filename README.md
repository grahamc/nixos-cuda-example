# NixOS: CUDA

# `configuration.nix`

This is essentialy the config parts I needed to add to
`/etc/nixos/configuration.nix` in order to have CUDA. Particularly note the
SystemD unit, this creates the `/dev/nvidia0`, `/dev/nvidia1`,
`/dev/nvidiactl` files.

# `./cuda-samples/`

This directory contains all the example CUDA code from NVIDIA's CUDA Toolkit,
and a nix expression. Once your system is working (try testing with
`nvidia-smi`,) go into that directory, run:

```
nix-build default.nix -A examplecuda
```

It will tell you in there where it put it, at which point you can run those
programs:

```
[grahamc@sc:/nix/store/a0v4qnwyr9ignk1mygncrk12cqarc58a-example-cuda/bin]$ ls
alignedTypes              MonteCarloMultiGPU
asyncAPI                  newdelete
bandwidthTest             p2pBandwidthLatencyTest
batchCUBLAS               ptxjit
binomialOptions           quasirandomGenerator
```

```
[grahamc@sc:~/nixos-cuda-k40]$ /nix/store/a0v4qnwyr9ignk1mygncrk12cqarc58a-example-cuda/bin/MonteCarloMultiGPU
/nix/store/a0v4qnwyr9ignk1mygncrk12cqarc58a-example-cuda/bin/MonteCarloMultiGPU Starting...

Using single CPU thread for multiple GPUs
MonteCarloMultiGPU
==================
Parallelization method  = streamed
Problem scaling         = weak
Number of GPUs          = 2
Total number of options = 16384
Number of paths         = 262144
main(): generating input data...
main(): starting 2 host threads...
main(): GPU statistics, streamed
GPU Device #0: Tesla K40c
Options         : 8192
Simulation paths: 262144
GPU Device #1: GeForce GT 740
Options         : 8192
Simulation paths: 262144

Total time (ms.): 344.402008
      Note: This is elapsed time for all to compute.
      Options per sec.: 47572.312637
      main(): comparing Monte Carlo and Black-Scholes results...
      Shutting down...
      Test Summary...
      L1 norm        : 4.836368E-04
      Average reserve: 11.301252

NOTE: The CUDA Samples are not meant for performance measurements. Results may vary when GPU Boost is enabled.

Test passed
```