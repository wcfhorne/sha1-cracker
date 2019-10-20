/* main.cpp
 * ECE-565, Project 3
 * Connor Horne
 * Brute force SHA1 cracker
 * code modfied from https://github.com/smoes/SHA1-CUDA-bruteforce
 */

#include "sha.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

using namespace std;

void help(void);

int main(int argc, char **argv) {

  int c;

  /// check for args, print help message
  while ((c = getopt(argc, argv, "h:")) != -1) {

    // handle optional arguments
    switch (c) {
    case 'h':
      help();
      exit(1);
    default:
      help();
      break;
    }
  }

  if ((argc - optind) != 1) {
    printf("sha required\n");
    exit(-1);
  }

  char input_string[41], tmp[8];
  unsigned char *result;

  word hash[5];
  strcpy(input_string, argv[1]);

  char input[40];
  memcpy(input, input_string, 40);

  // create split digest
  /// change to unsigned int
  for (int i = 0; i < 5; i++) {
    for (int j = 0; j < 8; j++)
      tmp[j] = input[i * 8 + j];

    hash[i] = strtol(tmp, NULL, 16);
  }

  // print uppercase
  printf("input:\t");
  for (int i = 0; i < 5; i++) {
    printf("%08x", hash[i]);
  }
  printf("\n");

  // create result matrix
  result = (uc *)malloc(80);
  for (int i = 0; i < 10; i++)
    result[i] = 0;

  // call the entrence to launching gpu kernel
  double time = crack(hash, result);

  /// print the time and result
  printf("time: %f\n", time);

  if (result[0] == 0) {
    printf("No hash found \n");
  } else {
    printf("found: %s\n", result);
  }

  free(result);

  return 0;
}

void help(void) {
  printf("crk sha\n");
  printf("Description: Break SHA1 hashes with CUDA\n");
  printf("sha: input sha1\n");
  printf("modified from https://github.com/smoes/SHA1-CUDA-bruteforce\n");
}
