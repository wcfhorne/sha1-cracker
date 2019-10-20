/* sha.h
 * ECE-565, Project 3
 * Connor Horne
 * Header for sha1 cuda functions
 */


#ifndef SHA_H
#define SHA_H

#define uc unsigned char
#define word unsigned int

/* crack
 * call a cuda based SHA1 bruteforce search method 
 * 
 * @hash is the input hash
 * @result is result of the cracking
 * @return double is the total time used 
 */
double crack(unsigned int * hash, unsigned char * result);

#endif
