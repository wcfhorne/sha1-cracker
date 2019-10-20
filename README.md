# Program cuda-sha1-cracker

## Overview

This program was developed as part of a competition to optimize an old piece of Cuda code. It did well, providing a x4-x21 speedup over the orginal code. Hopefully it will provide some guidence to others getting into GPU programming on optimizing code. I used the nsight profiler to look at register allocation, etc. I programmed it on BigRed2 so it was setup for compiling on a cluster.

The orginal code was based on https://github.com/smoes/SHA1-CUDA-bruteforce. It has no liscense so it is unknown what the resulting code is license under.

## Design of the Code

The design choices for optimizing the code include:
* Creating a earlier exit check.
* Moving it to a single kernel (this was a bad choice in retrospect).
* Replacing the array (which is in local memory) with variables to eliminate local memory access.
* Letting the threads overlap after testing the pure compute version.

## Possible Future Work
There is still some performance gains, as it was about 1/3 of the maximum performance of the GPU, a Tesla K20. Futher options to optimize this code include: templates/macros to eliminate thread divergence, intrinsics, and improving the early exit. Regardless, the kernel size needs to optimized for other hardware.

## To compile
On a regular computer/server. Use g++ and nvcc.
On a cluster. Use the compiler wrapper provided by your cluster and make sure that the nvcc compiler is loaded.

## To use

sha "target sha1 hash"

for example

sha ff0d41d2f06d3cf66cf1e7cfa7412eb9b4f7fa61

If issues, there are commented out lines that can overide the command line args.