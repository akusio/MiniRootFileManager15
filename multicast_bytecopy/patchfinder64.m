//
//  patchfinder64.c
//  extra_recipe
//
//  Created by xerub on 06/06/2017.
//  Copyright © 2017 xerub. All rights reserved.
//

#include <assert.h>
#include <stdint.h>
#include <string.h>

#include "kerneldec.h"

#import <Foundation/Foundation.h>

typedef unsigned long long addr_t;

#define IS64(image) (*(uint8_t *)(image) & 1)

#define MACHO(p) ((*(unsigned int *)(p) & ~1) == 0xfeedface)

/* generic stuff *************************************************************/

#define UCHAR_MAX 255

static unsigned char *
boyermoore_horspool_memmem(const unsigned char* haystack, size_t hlen,
                           const unsigned char* needle,   size_t nlen)
{
    size_t last, scan = 0;
    size_t bad_char_skip[UCHAR_MAX + 1]; /* Officially called:
                                          * bad character shift */

    /* Sanity checks on the parameters */
    if (nlen <= 0 || !haystack || !needle)
        return NULL;

    /* ---- Preprocess ---- */
    /* Initialize the table to default value */
    /* When a character is encountered that does not occur
     * in the needle, we can safely skip ahead for the whole
     * length of the needle.
     */
    for (scan = 0; scan <= UCHAR_MAX; scan = scan + 1)
        bad_char_skip[scan] = nlen;

    /* C arrays have the first byte at [0], therefore:
     * [nlen - 1] is the last byte of the array. */
    last = nlen - 1;

    /* Then populate it with the analysis of the needle */
    for (scan = 0; scan < last; scan = scan + 1)
        bad_char_skip[needle[scan]] = last - scan;

    /* ---- Do the matching ---- */

    /* Search the haystack, while the needle can still be within it. */
    while (hlen >= nlen)
    {
        /* scan from the end of the needle */
        for (scan = last; haystack[scan] == needle[scan]; scan = scan - 1)
            if (scan == 0) /* If the first byte matches, we've found it. */
                return (void *)haystack;

        /* otherwise, we need to skip some bytes and start again.
           Note that here we are getting the skip value based on the last byte
           of needle, no matter where we didn't match. So if needle is: "abcd"
           then we are skipping based on 'd' and that value will be 4, and
           for "abcdd" we again skip on 'd' but the value will be only 1.
           The alternative of pretending that the mismatched character was
           the last character is slower in the normal case (E.g. finding
           "abcd" in "...azcd..." gives 4 by using 'd' but only
           4-2==2 using 'z'. */
        hlen     -= bad_char_skip[haystack[last]];
        haystack += bad_char_skip[haystack[last]];
    }

    return NULL;
}

/* disassembler **************************************************************/


/* patchfinder ***************************************************************/

static addr_t
xref64(const uint8_t *buf, addr_t start, addr_t end, addr_t what)
{
    addr_t i;
    uint64_t value[32];

    memset(value, 0, sizeof(value));

    end &= ~3;
    for (i = start & ~3; i < end; i += 4) {
        uint32_t op = *(uint32_t *)(buf + i);
        unsigned reg = op & 0x1F;
        if ((op & 0x9F000000) == 0x90000000) {
            signed adr = ((op & 0x60000000) >> 18) | ((op & 0xFFFFE0) << 8);
            //printf("%llx: ADRP X%d, 0x%llx\n", i, reg, ((long long)adr << 1) + (i & ~0xFFF));
            value[reg] = ((long long)adr << 1) + (i & ~0xFFF);
            continue;				// XXX should not XREF on its own?
        /*} else if ((op & 0xFFE0FFE0) == 0xAA0003E0) {
            unsigned rd = op & 0x1F;
            unsigned rm = (op >> 16) & 0x1F;
            //printf("%llx: MOV X%d, X%d\n", i, rd, rm);
            value[rd] = value[rm];*/
        } else if ((op & 0xFF000000) == 0x91000000) {
            unsigned rn = (op >> 5) & 0x1F;
            unsigned shift = (op >> 22) & 3;
            unsigned imm = (op >> 10) & 0xFFF;
            if (shift == 1) {
                imm <<= 12;
            } else {
                //assert(shift == 0);
                if (shift > 1) continue;
            }
            //printf("%llx: ADD X%d, X%d, 0x%x\n", i, reg, rn, imm);
            value[reg] = value[rn] + imm;
        } else if ((op & 0xF9C00000) == 0xF9400000) {
            unsigned rn = (op >> 5) & 0x1F;
            unsigned imm = ((op >> 10) & 0xFFF) << 3;
            //printf("%llx: LDR X%d, [X%d, 0x%x]\n", i, reg, rn, imm);
            if (!imm) continue;			// XXX not counted as true xref
            value[reg] = value[rn] + imm;	// XXX address, not actual value
        /*} else if ((op & 0xF9C00000) == 0xF9000000) {
            unsigned rn = (op >> 5) & 0x1F;
            unsigned imm = ((op >> 10) & 0xFFF) << 3;
            //printf("%llx: STR X%d, [X%d, 0x%x]\n", i, reg, rn, imm);
            if (!imm) continue;			// XXX not counted as true xref
            value[rn] = value[rn] + imm;	// XXX address, not actual value*/
        } else if ((op & 0x9F000000) == 0x10000000) {
            signed adr = ((op & 0x60000000) >> 18) | ((op & 0xFFFFE0) << 8);
            //printf("%llx: ADR X%d, 0x%llx\n", i, reg, ((long long)adr >> 11) + i);
            value[reg] = ((long long)adr >> 11) + i;
        } else if ((op & 0xFF000000) == 0x58000000) {
            unsigned adr = (op & 0xFFFFE0) >> 3;
            //printf("%llx: LDR X%d, =0x%llx\n", i, reg, adr + i);
            value[reg] = adr + i;		// XXX address, not actual value
        }
        if (value[reg] == what) {
            return i;
        }
    }
    return 0;
}

static addr_t
calc64(const uint8_t *buf, addr_t start, addr_t end, int which)
{
    addr_t i;
    uint64_t value[32];

    memset(value, 0, sizeof(value));

    end &= ~3;
    for (i = start & ~3; i < end; i += 4) {
        uint32_t op = *(uint32_t *)(buf + i);
        unsigned reg = op & 0x1F;
        if ((op & 0x9F000000) == 0x90000000) {
            signed adr = ((op & 0x60000000) >> 18) | ((op & 0xFFFFE0) << 8);
            printf("%llx: ADRP X%d, 0x%llx\n", i, reg, ((long long)adr << 1) + (i & ~0xFFF));
            value[reg] = ((long long)adr << 1) + (i & ~0xFFF);
        /*} else if ((op & 0xFFE0FFE0) == 0xAA0003E0) {
            unsigned rd = op & 0x1F;
            unsigned rm = (op >> 16) & 0x1F;
            //printf("%llx: MOV X%d, X%d\n", i, rd, rm);
            value[rd] = value[rm];*/
        } else if ((op & 0xFF000000) == 0x91000000) {
            unsigned rn = (op >> 5) & 0x1F;
            unsigned shift = (op >> 22) & 3;
            unsigned imm = (op >> 10) & 0xFFF;
            if (shift == 1) {
                imm <<= 12;
            } else {
                //assert(shift == 0);
                if (shift > 1) continue;
            }
            //printf("%llx: ADD X%d, X%d, 0x%x\n", i, reg, rn, imm);
            value[reg] = value[rn] + imm;
        } else if ((op & 0xF9C00000) == 0xF9400000) {
            unsigned rn = (op >> 5) & 0x1F;
            unsigned imm = ((op >> 10) & 0xFFF) << 3;
            printf("%llx: LDR X%d, [X%d, 0x%x]\n", i, reg, rn, imm);
            if (!imm) continue;			// XXX not counted as true xref
            value[reg] = value[rn] + imm;	// XXX address, not actual value
        } else if ((op & 0xF9C00000) == 0xF9000000) {
            unsigned rn = (op >> 5) & 0x1F;
            unsigned imm = ((op >> 10) & 0xFFF) << 3;
            //printf("%llx: STR X%d, [X%d, 0x%x]\n", i, reg, rn, imm);
            if (!imm) continue;			// XXX not counted as true xref
            value[rn] = value[rn] + imm;	// XXX address, not actual value
        } else if ((op & 0x9F000000) == 0x10000000) {
            signed adr = ((op & 0x60000000) >> 18) | ((op & 0xFFFFE0) << 8);
            //printf("%llx: ADR X%d, 0x%llx\n", i, reg, ((long long)adr >> 11) + i);
            value[reg] = ((long long)adr >> 11) + i;
        } else if ((op & 0xFF000000) == 0x58000000) {
            unsigned adr = (op & 0xFFFFE0) >> 3;
            //printf("%llx: LDR X%d, =0x%llx\n", i, reg, adr + i);
            value[reg] = adr + i;		// XXX address, not actual value
        }
    }
    return value[which];
}



/* kernel iOS10 **************************************************************/

#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <mach-o/loader.h>
//#include "vfs.h" // img4lib

/*
#ifdef __ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__
#include <mach/mach.h>
size_t kread(uint64_t where, void *p, size_t size);
#endif
*/

#ifdef VFS_H_included
#define INVALID_HANDLE NULL
static FHANDLE
OPEN(const char *filename, int oflag)
{
    ssize_t rv;
    char buf[28];
    FHANDLE fd = file_open(filename, oflag);
    if (!fd) {
        return NULL;
    }
    rv = fd->read(fd, buf, 4);
    fd->lseek(fd, 0, SEEK_SET);
    if (rv == 4 && !MACHO(buf)) {
        fd = img4_reopen(fd, NULL, 0);
        if (!fd) {
            return NULL;
        }
        rv = fd->read(fd, buf, sizeof(buf));
        if (rv == sizeof(buf) && *(uint32_t *)buf == 0xBEBAFECA && __builtin_bswap32(*(uint32_t *)(buf + 4)) > 0) {
            return sub_reopen(fd, __builtin_bswap32(*(uint32_t *)(buf + 16)), __builtin_bswap32(*(uint32_t *)(buf + 20)));
        }
        fd->lseek(fd, 0, SEEK_SET);
    }
    return fd;
}
#define CLOSE(fd) (fd)->close(fd)
#define READ(fd, buf, sz) (fd)->read(fd, buf, sz)
static ssize_t
PREAD(FHANDLE fd, void *buf, size_t count, off_t offset)
{
    ssize_t rv;
    //off_t pos = fd->lseek(FHANDLE fd, 0, SEEK_CUR);
    fd->lseek(fd, offset, SEEK_SET);
    rv = fd->read(fd, buf, count);
    //fd->lseek(FHANDLE fd, pos, SEEK_SET);
    return rv;
}
#else
#define FHANDLE int
#define INVALID_HANDLE -1
#define OPEN open
#define CLOSE close
#define READ read
#define PREAD pread
#endif

static uint8_t *kernel = NULL;
static int kernel_version = 0;
static size_t kernel_size = 0;

static addr_t xnucore_base = 0;
static addr_t xnucore_size = 0;
static addr_t prelink_base = 0;
static addr_t prelink_size = 0;
static addr_t pplcode_base = 0;
static addr_t pplcode_size = 0;
static addr_t cstring_base = 0;
static addr_t cstring_size = 0;
static addr_t pstring_base = 0;
static addr_t pstring_size = 0;
static addr_t kerndumpbase = -1;
static addr_t kernel_entry = 0;
static void *kernel_mh = 0;
static addr_t kernel_delta = 0;

__attribute__((visibility("hidden")))
int
init_kernel(addr_t base, const char *filename)
{
    size_t rv;
    uint8_t buf[0x4000];
    uint8_t *vstr;
    unsigned i, j;
    const struct mach_header *hdr = (struct mach_header *)buf;
    FHANDLE fd = INVALID_HANDLE;
    const uint8_t *q;
    addr_t min = -1;
    addr_t max = 0;
    int is64 = 0;

    if (filename == NULL) {
        /*
#ifdef __ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__
        rv = kread(base, buf, sizeof(buf));
        if (rv != sizeof(buf) || !MACHO(buf)) {
            return -1;
        }
#else
         */
        (void)base;
        return -1;
        /*
#endif
         */
    } else {
        fd = OPEN(filename, O_RDONLY);
        if (fd == INVALID_HANDLE) {
            return -1;
        }
        rv = READ(fd, buf, sizeof(buf));
        if (rv != sizeof(buf) || !MACHO(buf)) {
            CLOSE(fd);
            return -1;
        }
    }

    if (IS64(buf)) {
        is64 = 4;
    }

    q = buf + sizeof(struct mach_header) + is64;
    for (i = 0; i < hdr->ncmds; i++) {
        const struct load_command *cmd = (struct load_command *)q;
        if (cmd->cmd == LC_SEGMENT_64 && ((struct segment_command_64 *)q)->vmsize) {
            const struct segment_command_64 *seg = (struct segment_command_64 *)q;
            if (min > seg->vmaddr) {
                min = seg->vmaddr;
            }
            if (max < seg->vmaddr + seg->vmsize) {
                max = seg->vmaddr + seg->vmsize;
            }
            if (!strcmp(seg->segname, "__TEXT_EXEC")) {
                xnucore_base = seg->vmaddr;
                xnucore_size = seg->filesize;
            }
            if (!strcmp(seg->segname, "__PLK_TEXT_EXEC")) {
                prelink_base = seg->vmaddr;
                prelink_size = seg->filesize;
            }
            if (!strcmp(seg->segname, "__PPLTEXT")) {
                pplcode_base = seg->vmaddr;
                pplcode_size = seg->filesize;
            }
            if (!strcmp(seg->segname, "__TEXT")) {
                const struct section_64 *sec = (struct section_64 *)(seg + 1);
                for (j = 0; j < seg->nsects; j++) {
                    if (!strcmp(sec[j].sectname, "__cstring")) {
                        cstring_base = sec[j].addr;
                        cstring_size = sec[j].size;
                    }
                }
            }
            if (!strcmp(seg->segname, "__PRELINK_TEXT")) {
                const struct section_64 *sec = (struct section_64 *)(seg + 1);
                for (j = 0; j < seg->nsects; j++) {
                    if (!strcmp(sec[j].sectname, "__text")) {
                        pstring_base = sec[j].addr;
                        pstring_size = sec[j].size;
                    }
                }
            }
        }
        if (cmd->cmd == LC_UNIXTHREAD) {
            uint32_t *ptr = (uint32_t *)(cmd + 1);
            uint32_t flavor = ptr[0];
            struct {
                uint64_t x[29];	/* General purpose registers x0-x28 */
                uint64_t fp;	/* Frame pointer x29 */
                uint64_t lr;	/* Link register x30 */
                uint64_t sp;	/* Stack pointer x31 */
                uint64_t pc; 	/* Program counter */
                uint32_t cpsr;	/* Current program status register */
            } *thread = (void *)(ptr + 2);
            if (flavor == 6) {
                kernel_entry = thread->pc;
            }
        }
        q = q + cmd->cmdsize;
    }

    if (pstring_base == 0 && pstring_size == 0) {
        pstring_base = cstring_base;
        pstring_size = cstring_size;
    }
    if (prelink_base == 0 && prelink_size == 0) {
        prelink_base = xnucore_base;
        prelink_size = xnucore_size;
    }

    kerndumpbase = min;
    xnucore_base -= kerndumpbase;
    prelink_base -= kerndumpbase;
    pplcode_base -= kerndumpbase;
    cstring_base -= kerndumpbase;
    pstring_base -= kerndumpbase;
    kernel_size = max - min;

    if (filename == NULL) {
        /*
#ifdef __ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__
        kernel = malloc(kernel_size);
        if (!kernel) {
            return -1;
        }
        rv = kread(kerndumpbase, kernel, kernel_size);
        if (rv != kernel_size) {
            free(kernel);
            kernel = NULL;
            return -1;
        }

        kernel_mh = kernel + base - min;
#endif
         */
    } else {
        kernel = calloc(1, kernel_size);
        if (!kernel) {
            CLOSE(fd);
            return -1;
        }

        q = buf + sizeof(struct mach_header) + is64;
        for (i = 0; i < hdr->ncmds; i++) {
            const struct load_command *cmd = (struct load_command *)q;
            if (cmd->cmd == LC_SEGMENT_64) {
                const struct segment_command_64 *seg = (struct segment_command_64 *)q;
                size_t sz = PREAD(fd, kernel + seg->vmaddr - min, seg->filesize, seg->fileoff);
                if (sz != seg->filesize) {
                    CLOSE(fd);
                    free(kernel);
                    kernel = NULL;
                    return -1;
                }
                if (!kernel_mh) {
                    kernel_mh = kernel + seg->vmaddr - min;
                }
                if (!strcmp(seg->segname, "__LINKEDIT")) {
                    kernel_delta = seg->vmaddr - min - seg->fileoff;
                }
            }
            q = q + cmd->cmdsize;
        }

        CLOSE(fd);
    }

    vstr = boyermoore_horspool_memmem(kernel, kernel_size, (uint8_t *)"Darwin Kernel Version", sizeof("Darwin Kernel Version") - 1);
    if (vstr) {
        kernel_version = atoi((const char *)vstr + sizeof("Darwin Kernel Version"));
    }

    return 0;
}

__attribute__((visibility("hidden")))
void
term_kernel(void)
{
    free(kernel);
}

/* these operate on VA ******************************************************/

#define INSN_RETAB  0xD65F0FFF, 0xFFFFFFFF
#define INSN_RET    0xD65F03C0, 0xFFFFFFFF
#define INSN_CALL   0x94000000, 0xFC000000
#define INSN_B      0x14000000, 0xFC000000
#define INSN_CBZ    0x34000000, 0xFC000000
#define INSN_BLR    0xD63F0000, 0xFFFFFC1F


static addr_t
find_reference(addr_t to, int n, int where)
{
    addr_t ref, end;
    addr_t base = xnucore_base;
    addr_t size = xnucore_size;
    switch (where) {
        case 1:
            base = prelink_base;
            size = prelink_size;
            break;
        case 2:
            base = pplcode_base;
            size = pplcode_size;
            break;
    }
    if (n <= 0) {
        n = 1;
    }
    end = base + size;
    to -= kerndumpbase;
    do {
        ref = xref64(kernel, base, end, to);
        if (!ref) {
            return 0;
        }
        base = ref + 4;
    } while (--n > 0);
    return ref + kerndumpbase;
}

static addr_t
find_strref(const char *string, int n, int where)
{
    uint8_t *str;
    addr_t base = cstring_base;
    addr_t size = cstring_size;
    switch (where) {
        case 1:
            base = pstring_base;
            size = pstring_size;
            break;
    }
    str = boyermoore_horspool_memmem(kernel + base, size, (uint8_t *)string, strlen(string));
    if (!str) {
        return 0;
    }
    return find_reference(str - kernel + kerndumpbase, n, where);
}


/* extra_recipe **************************************************************/

#define INSN_STR8 0xF9000000 | 8, 0xFFC00000 | 0x1F
#define INSN_POPS 0xA9407BFD, 0xFFC07FFF


addr_t find_allproc(void)
{
    addr_t val;
    addr_t ref = find_strref("shutdownwait", 1, 0);
    if (!ref) {
        return 0;
    }
    ref -= kerndumpbase;
    val = calc64(kernel, ref, ref + 24, 8);
    if (!val) {
        return 0;
    }
    return val + kerndumpbase;
}

uint64_t find_kauth_cred_table_anchor(void){
    
    uint32_t* start = (uint32_t*)kernel;
    uint32_t* current = start;
    uint32_t* end = (uint32_t*)(kernel + kernel_size);
    uint32_t and_x8_x8_0x7f = 0x12001908;
    uint32_t retab = 0xD65F0FFF;
    addr_t val = 0;
    
    while(end > current){
        
        if(*current == and_x8_x8_0x7f){
            //printf("0x%llx : and x8, x8, #7f\n", (uint8_t*)current - kernel + kerndumpbase);
            
            if(*(current + 5) == retab){
                
                val = calc64(kernel, (uint8_t*)current - kernel, (uint8_t*)current - kernel + 12, 9);
                if(val == 0){
                    current++;
                    continue;
                }
                
                printf("kauth_cred_table_anchor : 0x%llx\n", val + kerndumpbase);
                break;
            }
            
        }
        
        current++;
        
    }
    
    if(val == 0){
        return 0;
    }
    
    return val + kerndumpbase;
    
}

#define HAVE_MAIN

#ifdef HAVE_MAIN

/* test **********************************************************************/

    
    

#endif	/* HAVE_MAIN */
