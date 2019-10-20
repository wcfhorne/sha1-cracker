/* sha.cu
 * ECE-565, Project 3
 * Connor Horne
 * Cuda routine for sha1 cracking
 */

#include "sha.h"
#include <stdio.h>

// launch the kernel
//@
//@
//@
void launch(word *hash_tmp, unsigned char *result);

// kernel entrence to brute force sha test
// @ device_result is result from the SHA crack
// @ device_hash is the input hash
__global__ void smash(volatile unsigned char *device_result,
                      unsigned int *device_hash);

// prepares W for SHA1
// @ W is 80 int array for sha calculation
// @ test word is the ascii array of the test word
// @ length is the length of the indies that are being tested
__device__ void memInit(unsigned int *W, unsigned char *test_word, int length);

// initialize word to global mem
// @test is 8 unsigned char array to hold test word vals
__device__ int initTestWord(unsigned char *test);

// shift the word by block*dim
// @test is 8 unsigned test word
// @loc is the global location of the thread
__device__ int shift(unsigned char *test, unsigned long long *loc);

// Main loop SHA logical functions f1 to f4
__device__ inline word f1(word x, word y, word z) {
  return ((x & y) | (~x & z));
}
__device__ inline word f2(word x, word y, word z) { return (x ^ y ^ z); }
__device__ inline word f3(word x, word y, word z) {
  return ((x & y) | (x & z) | (y & z));
}
__device__ inline word f4(word x, word y, word z) { return (x ^ y ^ z); }

// SHA init constants
#define I1 1732584193U
#define I2 4023233417U
#define I3 2562383102U
#define I4 271733878U
#define I5 3285377520U

// 32-bit rotate
__device__ inline word ROT(word x, int n) {
  return ((x << n) | (x >> (32 - n)));
}

// calculation functions for 80 rounds of SHA1
#define CALC1(i)                                                               \
  temp = ROT(A, 5) + f1(B, C, D) + W[i] + E + 1518500249U;                     \
  E = D;                                                                       \
  D = C;                                                                       \
  C = ROT(B, 30);                                                              \
  B = A;                                                                       \
  A = temp

#define CALC2(i)                                                               \
  temp = ROT(A, 5) + f2(B, C, D) + W[i] + E + 1859775393U;                     \
  E = D;                                                                       \
  D = C;                                                                       \
  C = ROT(B, 30);                                                              \
  B = A;                                                                       \
  A = temp

#define CALC3(i)                                                               \
  temp = ROT(A, 5) + f3(B, C, D) + W[i] + E + 2400959708U;                     \
  E = D;                                                                       \
  D = C;                                                                       \
  C = ROT(B, 30);                                                              \
  B = A;                                                                       \
  A = temp

#define CALC4(i)                                                               \
  temp = ROT(A, 5) + f4(B, C, D) + W[i] + E + 3395469782U;                     \
  E = D;                                                                       \
  D = C;                                                                       \
  C = ROT(B, 30);                                                              \
  B = A;                                                                       \
  A = temp

// ascii constants constants
#define HIGH 126
#define LOW 32
#define BASE 95

// set the max search depth
#define MAX 6

// Offsets for 95^x
#define OFFSET1 95LL
#define OFFSET2 9120LL
#define OFFSET3 866495LL
#define OFFSET4 82317120LL
#define OFFSET5 7820126495LL
#define OFFSET6 742912017120LL
#define OFFSET7 70576641626495LL
#define OFFSET8 6704780954517120LL

// Launch Kernel Code
void launch(word *input_hash, unsigned char *result) {

  // device result is the found hash from the kernel run, cuda memory
  // device hash is input hash
  unsigned char *device_result;
  word *device_hash;

  cudaMalloc((void **)&device_result, 10 * sizeof(unsigned char));
  cudaMalloc((void **)&device_hash, 5 * sizeof(word));

  cudaMemcpy(device_hash, input_hash, 5 * sizeof(word), cudaMemcpyHostToDevice);
  cudaMemset(device_result, 0, 10 * sizeof(unsigned char));

  // cuda timing of kernel
  cudaEvent_t start, stop;
  cudaEventCreate(&start);
  cudaEventCreate(&stop);

  cudaEventRecord(start);

  // call the kenel for searching for values

  // smash<<<1, 32>>>(max, device_result, device_hash);
  // smash<<<14,192>>>(max, device_result, device_hash);
  // smash<<<14, 1024>>>(device_result, device_hash);

  // 40 warps
  // this warp is faster than 100% occupency
  // smash<<<14*5, 256>>>(device_result, device_hash);

  // this with reg limit of 32 achieves 100% occupency with
  // -maxregcount 32
  smash<<<14 * 16, 128>>>(device_result, device_hash);

  cudaEventRecord(stop);

  cudaEventSynchronize(stop);

  // get possibly found result back from kernel
  cudaMemcpy(result, device_result, 10 * sizeof(unsigned char),
             cudaMemcpyDeviceToHost);

  cudaError_t err = cudaGetLastError();
  if (cudaSuccess != err)
    printf("Cuda error: %s.\n", cudaGetErrorString(err));

  float milliseconds = 0;
  cudaEventElapsedTime(&milliseconds, start, stop);

  printf("kernel time: %.1f ms\n", milliseconds);

  // free mem
  cudaEventDestroy(start);
  cudaEventDestroy(stop);
  cudaFree(device_hash);
  cudaFree(device_result);
}

// call function from non-cuda code
double crack(unsigned int *hash, unsigned char *result) {

  double time = 0;

  // time the entire kernel launch process
  clock_t test = clock();

  // call wrapper of kernel lanch
  launch(hash, result);

  time = ((double)clock() - test) / CLOCKS_PER_SEC;

  return time;
}

__global__ void smash(volatile unsigned char *result, word *hash) {

  int gtid = (blockDim.x * blockIdx.x) + threadIdx.x;

  // need to make sure this is placed in registers
  // unsigned char test_word[MAX];
  unsigned char test_word[8];

  word h0, h1, h2, h3, h4;

  // load input hash into local var
  h0 = hash[0];
  h1 = hash[1];
  h2 = hash[2];
  h3 = hash[3];
  h4 = hash[4];

  // initil test word
  // force word into registers
  test_word[0] = 0;
  test_word[1] = 0;
  test_word[2] = 0;
  test_word[3] = 0;
  test_word[4] = 0;
  test_word[5] = 0;
  test_word[6] = 0;
  test_word[7] = 0;

  // sets the test word to the gtid
  int length = initTestWord(test_word);

  // vars for SHA1 calc
  word W[80], A, B, C, D, E, temp;

  // init search position
  unsigned long long loc = gtid;

  while ((result[0] == 0) && (length < 7)) {

    // convert the test word to proper format for SHA
    // places bit representation in steps of 8
    // appends 8 to end and length to end
    memInit(W, test_word, length);

    // calculate sha1
    // unroll this loop to make sure W is placed in registers
#pragma unroll
    for (int i = 16; i < 80; i++) {
      W[i] = ROT((W[i - 3] ^ W[i - 8] ^ W[i - 14] ^ W[i - 16]), 1);
    }

    // Perform sha calculation
    A = I1;
    B = I2;
    C = I3;
    D = I4;
    E = I5;

    // 80 rounds
    CALC1(0);
    CALC1(1);
    CALC1(2);
    CALC1(3);
    CALC1(4);
    CALC1(5);
    CALC1(6);
    CALC1(7);
    CALC1(8);
    CALC1(9);
    CALC1(10);
    CALC1(11);
    CALC1(12);
    CALC1(13);
    CALC1(14);
    CALC1(15);
    CALC1(16);
    CALC1(17);
    CALC1(18);
    CALC1(19);
    CALC2(20);
    CALC2(21);
    CALC2(22);
    CALC2(23);
    CALC2(24);
    CALC2(25);
    CALC2(26);
    CALC2(27);
    CALC2(28);
    CALC2(29);
    CALC2(30);
    CALC2(31);
    CALC2(32);
    CALC2(33);
    CALC2(34);
    CALC2(35);
    CALC2(36);
    CALC2(37);
    CALC2(38);
    CALC2(39);
    CALC3(40);
    CALC3(41);
    CALC3(42);
    CALC3(43);
    CALC3(44);
    CALC3(45);
    CALC3(46);
    CALC3(47);
    CALC3(48);
    CALC3(49);
    CALC3(50);
    CALC3(51);
    CALC3(52);
    CALC3(53);
    CALC3(54);
    CALC3(55);
    CALC3(56);
    CALC3(57);
    CALC3(58);
    CALC3(59);
    CALC4(60);
    CALC4(61);
    CALC4(62);
    CALC4(63);
    CALC4(64);
    CALC4(65);
    CALC4(66);
    CALC4(67);
    CALC4(68);
    CALC4(69);
    CALC4(70);
    CALC4(71);
    CALC4(72);
    CALC4(73);
    CALC4(74);
    CALC4(75);
    CALC4(76);
    CALC4(77);
    CALC4(78);
    CALC4(79);

    A += I1;
    B += I2;
    C += I3;
    D += I4;
    E += I5;

    // check if the sha generated from test is equal to input sha
    // if true fill results buffer
    if (A == h0 && B == h1 && C == h2 && D == h3 && E == h4) {
      result[0] = test_word[0];
      result[1] = test_word[1];
      result[2] = test_word[2];
      result[3] = test_word[3];
      result[4] = test_word[4];
      result[5] = test_word[5];
      result[6] = test_word[6];
      result[7] = test_word[7];
    }

    // shift the word by a stride length of block*grid
    length = shift(test_word, &loc);
  }
  return;
}

/*
 * device function __device__ void memInit(uint, uchar, int)
 *
 * Prepare word for sha-1 (expand, add length etc)
 */
// could make various length based template versions
// can then unroll first for loop
__device__ void memInit(word *tmp, unsigned char input[], int length) {

// zero W array
// unroll it for placement in registers
#pragma unroll
  for (int i = 0; i < 80; i++) {
    tmp[i] = 0;
  }

  // switch statement
  // necessary in this single kernel launch
  // will result in input and W being placed in registers
  // in general will take words up to length and logical
  // or them into the word array's index (want chars as bits)
  // then append hex 80 to the last position after chars
  switch (length) {
  case 1:
    tmp[0] |= input[0] << 24;
    tmp[0] |= 128 << 16;

    break;
  case 2:
    tmp[0] |= input[0] << 24;
    tmp[0] |= input[1] << 16;
    tmp[0] |= 128 << 8;

    break;
  case 3:
    tmp[0] |= input[0] << 24;
    tmp[0] |= input[1] << 16;
    tmp[0] |= input[2] << 8;
    tmp[0] |= 128;

    break;
  case 4:
    tmp[0] |= input[0] << 24;
    tmp[0] |= input[1] << 16;
    tmp[0] |= input[2] << 8;
    tmp[0] |= input[3];
    tmp[1] |= (unsigned int)128 << 24;

    break;
  case 5:
    tmp[0] |= input[0] << 24;
    tmp[0] |= input[1] << 16;
    tmp[0] |= input[2] << 8;
    tmp[0] |= input[3];
    tmp[1] |= input[4] << 24;
    tmp[1] |= 128 << 16;

    break;
  case 6:
    tmp[0] |= input[0] << 24;
    tmp[0] |= input[1] << 16;
    tmp[0] |= input[2] << 8;
    tmp[0] |= input[3];
    tmp[1] |= input[4] << 24;
    tmp[1] |= input[5] << 16;
    tmp[1] |= 128 << 8;

    break;
  case 7:
    tmp[0] |= input[0] << 24;
    tmp[0] |= input[1] << 16;
    tmp[0] |= input[2] << 8;
    tmp[0] |= input[3];
    tmp[1] |= input[4] << 24;
    tmp[1] |= input[5] << 16;
    tmp[1] |= input[6] << 8;
    tmp[1] |= (unsigned int)128 << 24;

    break;
  }

  // Add length to end
  tmp[15] |= length * 8;
}

/*
 *
 *
 */
__device__ int initTestWord(unsigned char *test_word) {

  int gtid = (blockDim.x * blockIdx.x) + threadIdx.x;

  int length = 0;
  unsigned long long temp = gtid;

  // as there is a single kernel it can be offset by the previous search
  // one space goes from 0-94 and two spaces goes from 0-9025 but as its
  // running off of a striding global var then its from 95-9120 and
  // so on
  // this could be mitigated with muliple kernels and would probably
  // decrease the register count
  unsigned long long offset1 = 95;
  unsigned long long offset2 = (95 * 95) + 95;
  unsigned long long offset3 = (95 * 95 * 95) + (95 * 95) + 95;
  unsigned long long offset4 =
      (95 * 95 * 95 * 95) + (95 * 95 * 95) + (95 * 95) + 95;
  unsigned long long offset5 = (95LL * 95 * 95 * 95 * 95) +
                               (95LL * 95 * 95 * 95) + (95LL * 95 * 95) +
                               (95LL * 95) + 95LL;
  unsigned long long offset6 =
      (95LL * 95 * 95 * 95 * 95 * 95) + (95LL * 95 * 95 * 95 * 95) +
      (95LL * 95 * 95 * 95) + (95LL * 95 * 95) + (95LL * 95) + 95LL;

  // check if if num is above offset, if it is remove offset and
  // set all indicies to 32
  // this setup is designed to get compiler to place in registers
  // should be able to remove the first couple if statments as there is no
  // way that it could equal it here
  // note that 32 is the ascii offset
  if ((temp / offset6) > 0) {
    temp = temp - offset6;
    length = 7;

    test_word[0] = 32;
    test_word[1] = 32;
    test_word[2] = 32;
    test_word[3] = 32;
    test_word[4] = 32;
    test_word[5] = 32;
    test_word[6] = 32;
  } else if ((temp / offset5) > 0) {
    temp = temp - offset5;
    length = 6;

    test_word[0] = 32;
    test_word[1] = 32;
    test_word[2] = 32;
    test_word[3] = 32;
    test_word[4] = 32;
    test_word[5] = 32;
  } else if ((temp / offset4) > 0) {
    temp = temp - offset4;
    length = 5;

    test_word[0] = 32;
    test_word[1] = 32;
    test_word[2] = 32;
    test_word[3] = 32;
    test_word[4] = 32;

  } else if ((temp / offset3) > 0) {
    temp = temp - offset3;
    length = 4;

    test_word[0] = 32;
    test_word[1] = 32;
    test_word[2] = 32;
    test_word[3] = 32;

  } else if ((temp / offset2) > 0) {
    temp = temp - offset2;
    length = 3;

    test_word[0] = 32;
    test_word[1] = 32;
    test_word[2] = 32;

  } else if ((temp / offset1) > 0) {
    temp = temp - offset1;
    length = 2;

    test_word[0] = 32;
    test_word[1] = 32;

  } else {
    length = 1;

    test_word[0] = 32;
  }

// perform a base conversion with 95
// as the result will be 0 if nothing present, can
// safetly unroll and use as dummy result for
// nesseacery place word in registers
#pragma unroll
  for (int i = 0; i < 8; i++) {
    test_word[i] += (unsigned char)(temp % BASE);
    temp /= BASE;
  }

  return length;
}

// increment word by stride length
__device__ int shift(unsigned char *test_word, unsigned long long *loc) {

  // get stride length and increment the global location
  int stride = (blockDim.x * gridDim.x);
  (*loc) += (unsigned long long)stride;

  unsigned long long temp = *loc;

  int length = 0;

  // see initword function for details
  unsigned long long offset1 = 95;
  unsigned long long offset2 = (95 * 95) + 95;
  unsigned long long offset3 = (95 * 95 * 95) + (95 * 95) + 95;
  unsigned long long offset4 =
      (95 * 95 * 95 * 95) + (95 * 95 * 95) + (95 * 95) + 95;
  unsigned long long offset5 = (95LL * 95 * 95 * 95 * 95) +
                               (95LL * 95 * 95 * 95) + (95LL * 95 * 95) +
                               (95LL * 95) + 95LL;
  unsigned long long offset6 =
      (95LL * 95 * 95 * 95 * 95 * 95) + (95LL * 95 * 95 * 95 * 95) +
      (95LL * 95 * 95 * 95) + (95LL * 95 * 95) + (95LL * 95) + 95LL;

  // see initword function for more details
  // remove offset, set length, set words to ascii offset
  if ((temp / offset6) > 0) {
    temp = temp - offset6;
    length = 7;

    test_word[0] = 32;
    test_word[1] = 32;
    test_word[2] = 32;
    test_word[3] = 32;
    test_word[4] = 32;
    test_word[5] = 32;
    test_word[6] = 32;

  } else if ((temp / offset5) > 0) {
    temp = temp - offset5;
    length = 6;

    test_word[0] = 32;
    test_word[1] = 32;
    test_word[2] = 32;
    test_word[3] = 32;
    test_word[4] = 32;
    test_word[5] = 32;

  } else if ((temp / offset4) > 0) {
    temp = temp - offset4;
    length = 5;

    test_word[0] = 32;
    test_word[1] = 32;
    test_word[2] = 32;
    test_word[3] = 32;
    test_word[4] = 32;
  } else if ((temp / offset3) > 0) {
    temp = temp - offset3;
    length = 4;

    test_word[0] = 32;
    test_word[1] = 32;
    test_word[2] = 32;
    test_word[3] = 32;
  } else if ((temp / offset2) > 0) {
    temp = temp - offset2;
    length = 3;

    test_word[0] = 32;
    test_word[1] = 32;
    test_word[2] = 32;

  } else if ((temp / offset1) > 0) {
    temp = temp - offset1;
    length = 2;

    test_word[0] = 32;
    test_word[1] = 32;
  } else {
    length = 1;

    test_word[0] = 32;
  }

// ensure that compiler places in registers
// if result is greater, will be dummy result
// and will not harm the word
#pragma unroll
  for (int i = 0; i < 8; i++) {
    test_word[i] += (unsigned char)(temp % BASE);
    temp /= BASE;
  }

  return length;
}
