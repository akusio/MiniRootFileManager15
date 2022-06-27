//
//  kstruct.h
//  multicast_bytecopy
//
//  Created by akusio on 2022/05/10.
//

#ifndef kstruct_h
#define kstruct_h

#include <stdlib.h>
#include <stdio.h>
#include <sys/queue.h>

struct ucred {
    LIST_ENTRY(ucred)       cr_link; /* never modify this without KAUTH_CRED_HASH_LOCK */
    volatile u_long         cr_ref;  /* reference count */

    struct posix_cred {
        /*
         * The credential hash depends on everything from this point on
         * (see kauth_cred_get_hashkey)
         */
        uid_t   cr_uid;         /* effective user id */
        uid_t   cr_ruid;        /* real user id */
        uid_t   cr_svuid;       /* saved user id */
        u_short cr_ngroups;     /* number of groups in advisory list */
        
        //u_short __cr_padding;
        
        gid_t   cr_groups[NGROUPS];/* advisory group list */
        gid_t   cr_rgid;        /* real group id */
        gid_t   cr_svgid;       /* saved group id */
        uid_t   cr_gmuid;       /* UID for group membership purposes */
        int     cr_flags;       /* flags on credential */
    } cr_posix;
    void* cr_label;     /* MAC label */

    /*
     * NOTE: If anything else (besides the flags)
     * added after the label, you must change
     * kauth_cred_find().
     */
    struct au_session cr_audit;             /* user auditing data */
};

#endif /* kstruct_h */
