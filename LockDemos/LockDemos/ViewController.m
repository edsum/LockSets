//
//  ViewController.m
//  LockDemos
//
//  Created by Iean on 2017/11/6.
//  Copyright © 2017年 Iean. All rights reserved.
//

#import "ViewController.h"
//include <linux/spinlock.h>
#import <pthread.h>
#import <os/lock.h>

// 定义block类型
typedef void(^MMBlock)(void);

#define MM_GLOBAL_QUEUE(block) \
dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ \
while (1) { \
block();\
}\
})

@interface ViewController ()
{
    NSInteger _testInt;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//=================================================================
//                           互斥锁
//=================================================================
#pragma mark - 互斥锁

/**
 @synchronized
 */
- (void)mutexLockOfSynchronized:(NSInteger)testInt {
    @synchronized (self) {
        _testInt = testInt;
    }
}

/**
 NSLock
 */

- (void)mutexLOfNSLock {
    NSLock *lock = [[NSLock alloc] init];
    MMBlock block = ^{
        [lock lock];
        NSLog(@"执行操作");
        sleep(1);
        [lock unlock];
    };
    MM_GLOBAL_QUEUE(block);
}


/**
pthread
 */
// 摘录于YYKit
static inline void pthread_mutex_init_recursive(pthread_mutex_t *mutex, bool recursive) {
#define YYMUTEX_ASSERT_ON_ERROR(x_) do { \
__unused volatile int res = (x_); \
assert(res == 0); \
} while (0)
    assert(mutex != NULL);
    if (!recursive) {
        //普通锁
        YYMUTEX_ASSERT_ON_ERROR(pthread_mutex_init(mutex, NULL));
    } else {
        //递归锁
        pthread_mutexattr_t attr;
        YYMUTEX_ASSERT_ON_ERROR(pthread_mutexattr_init (&attr));
        YYMUTEX_ASSERT_ON_ERROR(pthread_mutexattr_settype (&attr, PTHREAD_MUTEX_RECURSIVE));
        YYMUTEX_ASSERT_ON_ERROR(pthread_mutex_init (mutex, &attr));
        YYMUTEX_ASSERT_ON_ERROR(pthread_mutexattr_destroy (&attr));
    }
#undef YYMUTEX_ASSERT_ON_ERROR
}

// 测试代码
- (void)mutexLockOfPthread {
        __block pthread_mutex_t lock;
        pthread_mutex_init_recursive(&lock,false);
        
        MMBlock block0=^{
            NSLog(@"线程 0：加锁");
            pthread_mutex_lock(&lock);
            NSLog(@"线程 0：睡眠 1 秒");
            sleep(1);
            pthread_mutex_unlock(&lock);
            NSLog(@"线程 0：解锁");
        };
        MM_GLOBAL_QUEUE(block0);
        
        MMBlock block1=^(){
            NSLog(@"线程 1：加锁");
            pthread_mutex_lock(&lock);
            NSLog(@"线程 1：睡眠 2 秒");
            sleep(2);
            pthread_mutex_unlock(&lock);
            NSLog(@"线程 1：解锁");
        };
        MM_GLOBAL_QUEUE(block1);
        
        MMBlock block2=^{
            NSLog(@"线程 2：加锁");
            pthread_mutex_lock(&lock);
            NSLog(@"线程 2：睡眠 3 秒");
            sleep(3);
            pthread_mutex_unlock(&lock);
            NSLog(@"线程 2：解锁");
        };
        MM_GLOBAL_QUEUE(block2);
}

//=================================================================
//                           递归锁
//=================================================================
#pragma mark - 递归锁

// NSLock造成死锁情况
- (void)deadlyLockOfNSLock {
    NSLock *lock = [[NSLock alloc] init];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        static void (^RecursiveMethod)(int);
        
        RecursiveMethod = ^(int value) {
            
            [lock lock];
            if (value > 0) {
                
                NSLog(@"value = %d", value);
                sleep(2);
                RecursiveMethod(value - 1);
            }
            [lock unlock];
        };
        
        RecursiveMethod(5);
    });
}

/**
 NSRecursiveLock
 */
- (void)recursionLockOfNSRecursiveLock {
    NSRecursiveLock *lock = [[NSRecursiveLock alloc] init];
    MM_GLOBAL_QUEUE(^{
        static void (^RecursiveBlock)(int);
        RecursiveBlock = ^(int value) {
            [lock lock];
            if (value > 0) {
                NSLog(@"加锁层数 %d", value);
                sleep(1);
                RecursiveBlock(--value);
            }
            [lock unlock];
        };
        RecursiveBlock(3);
    });
}

/**
 pthread
 */
- (void)recursionLockOfPthread {
    __block pthread_mutex_t lock;
    //第二个参数为true生成递归锁
    pthread_mutex_init_recursive(&lock,true);
    
    MM_GLOBAL_QUEUE(^{
        static void (^RecursiveBlock)(int);
        RecursiveBlock = ^(int value) {
            pthread_mutex_lock(&lock);
            if (value > 0) {
                NSLog(@"加锁层数 %d", value);
                sleep(1);
                RecursiveBlock(--value);
            }
            pthread_mutex_unlock(&lock);
        };
        RecursiveBlock(3);
    });
}


//=================================================================
//                           信号量
//=================================================================
#pragma mark - 信号量

/**
 dispatchsemaphoret
 */
- (void)semaphoreLockOfDispatchsemaphoret {
    // 参数可以理解为信号的总量，传入的值必须大于或等于0，否则，返回NULL
    // dispatch_semaphore_signal + 1
    // dispatch_semaphore_wait等待信号，当 <= 0会进入等待状态
    __block dispatch_semaphore_t semaphore = dispatch_semaphore_create(1);
    MM_GLOBAL_QUEUE(^{
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        NSLog(@"这里简单写一下用法，可自行实现生产者、消费者");
        sleep(1);
        dispatch_semaphore_signal(semaphore);
    });
}

/**
 pthread
 */
- (void)semaphoreLockOfPthread {
    __block pthread_mutex_t mutex=PTHREAD_MUTEX_INITIALIZER;
    __block pthread_cond_t cond=PTHREAD_COND_INITIALIZER;
    
    MM_GLOBAL_QUEUE(^{
        //NSLog(@"线程 0：加锁");
        pthread_mutex_lock(&mutex);
        pthread_cond_wait(&cond, &mutex);
        NSLog(@"线程 0：wait");
        pthread_mutex_unlock(&mutex);
        //NSLog(@"线程 0：解锁");
    });
    
    MM_GLOBAL_QUEUE(^{
        //NSLog(@"线程 1：加锁");
        sleep(3);//3秒发一次信号
        pthread_mutex_lock(&mutex);
        NSLog(@"线程 1：signal");
        pthread_cond_signal(&cond);
        pthread_mutex_unlock(&mutex);
        //NSLog(@"线程 1：加锁");
    });
}

//=================================================================
//                           条件锁
//=================================================================
#pragma mark - 条件锁


/**
 NSCodition
 */
- (void)executeNSCondition {
    NSCondition* lock = [[NSCondition alloc] init];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (NSUInteger i=0; i<3; i++) {
            sleep(2);
            if (i == 2) {
                [lock lock];
                [lock broadcast];
                [lock unlock];
            }
            
        }
    });
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(1);
        [self threadMethodOfNSCodition:lock];
    });
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(1);
        [self threadMethodOfNSCodition:lock];
    });
    
    
}

-(void)threadMethodOfNSCodition:(NSCondition*)lock{
    [lock lock];
    [lock wait];
    [lock unlock];
    
}

/**
 NSCoditionLock
 */
- (void)executeNSConditionLock {
    NSConditionLock* lock = [[NSConditionLock alloc] init];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (NSUInteger i=0; i<3; i++) {
            sleep(2);
            if (i == 2) {
                [lock lock];
                [lock unlockWithCondition:i];
            }
            
        }
    });
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(1);
        [self threadMethodOfNSCoditionLock:lock];
    });
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(1);
        [self threadMethodOfNSCoditionLock:lock];
    });
    
    
}

-(void)threadMethodOfNSCoditionLock:(NSConditionLock*)lock{
    [lock lockWhenCondition:2];
    [lock unlock];
    
}

/**
 pthread
 */
pthread_mutex_t mutex;
pthread_cond_t condition;
Boolean     ready_to_go = true;
void MyCondInitFunction()
{
    pthread_mutex_init(&mutex, NULL);
    pthread_cond_init(&condition, NULL);
}
void MyWaitOnConditionFunction()
{
    // Lock the mutex.
    pthread_mutex_lock(&mutex);
    // If the predicate is already set, then the while loop is bypassed;
    // otherwise, the thread sleeps until the predicate is set.
    while(ready_to_go == false)
    {
        pthread_cond_wait(&condition, &mutex);
    }
    // Do work. (The mutex should stay locked.)
    // Reset the predicate and release the mutex.
    ready_to_go = false;
    pthread_mutex_unlock(&mutex);
}
void SignalThreadUsingCondition()
{
    // At this point, there should be work for the other thread to do.
    pthread_mutex_lock(&mutex);
    ready_to_go = true;
    // Signal the other thread to begin work.
    pthread_cond_signal(&condition);
    pthread_mutex_unlock(&mutex);
}

//=================================================================
//                           分布式锁
//=================================================================
#pragma mark - 分布式锁


/**
 NSDistributedLock
 */
// Mac OS 下开发才能用到
/*
- (void)distributingLockOfNSDistributedLock {
    NSDistributedLock *lock = [[NSDistributedLock alloc] initWithPath:@"/Users/mac/Desktop/lock.lock"];
    while (![lock tryLock])
    {
        sleep(1);
    }
    //do something
    [lock unlock];
}
 */

//=================================================================
//                           读写锁
//=================================================================
#pragma mark - 读写锁

/**
 dispatch_barrier_async / dispatch_barrier_sync
 */
- (void)rwLockOfBarrier {
    dispatch_queue_t queue = dispatch_queue_create("thread", DISPATCH_QUEUE_CONCURRENT);

    dispatch_async(queue, ^{
        NSLog(@"test1");
    });
    dispatch_async(queue, ^{
        NSLog(@"test2");
    });
    dispatch_async(queue, ^{
        NSLog(@"test3");
    });
    dispatch_barrier_sync(queue, ^{
        for (int i = 0; i <= 500000000; i++) {
            if (5000 == i) {
                NSLog(@"point1");
            }else if (6000 == i) {
                NSLog(@"point2");
            }else if (7000 == i) {
                NSLog(@"point3");
            }
        }
        NSLog(@"barrier");
    });
    NSLog(@"aaa");
    dispatch_async(queue, ^{
        NSLog(@"test4");
    });
    dispatch_async(queue, ^{
        NSLog(@"test5");
    });
    dispatch_async(queue, ^{
        NSLog(@"test6");
    });
}

- (void)rwLockOfPthread {
    __block pthread_rwlock_t rwlock;
    pthread_rwlock_init(&rwlock,NULL);
    
    //读
    MM_GLOBAL_QUEUE(^{
        //NSLog(@"线程0：随眠 1 秒");//还是不打印能直观些
        sleep(1);
        NSLog(@"线程0：加锁");
        pthread_rwlock_rdlock(&rwlock);
        NSLog(@"线程0：读");
        pthread_rwlock_unlock(&rwlock);
        NSLog(@"线程0：解锁");
    });
    //写
    MM_GLOBAL_QUEUE(^{
        //NSLog(@"线程1：随眠 3 秒");
        sleep(3);
        NSLog(@"线程1：加锁");
        pthread_rwlock_wrlock(&rwlock);
        NSLog(@"线程1：写");
        pthread_rwlock_unlock(&rwlock);
        NSLog(@"线程1：解锁");
    });
}

//=================================================================
//                           自旋锁
//=================================================================
#pragma mark - 自旋锁

/**
 OSSpinLock
 */
// include <linux/spinlock.h> 无法导入头文件
- (void)pinLockOfOSSpinkLock {
    
    // 初始化
//    spinLock = OS_SPINKLOCK_INIT;
    // 加锁
//    OSSpinLockLock(&spinLock);
    // 解锁
//    OSSpinLockUnlock(&spinLock);
}

/**
 os_unfair_lock
 */
// #import <os/lock.h> ,需要导入头文件
- (void)pinLockOfOs_unfair_lock {
    os_unfair_lock_t unfairLock;
    unfairLock = &(OS_UNFAIR_LOCK_INIT);
    os_unfair_lock_lock(unfairLock);
    os_unfair_lock_unlock(unfairLock);
}

//=================================================================
//                           原子锁
//=================================================================
#pragma mark - 原子锁
// 默认不标记为 nonatomic，则为 atomic，即加了原子锁
//@property (nonatomic, copy) NSString *name;

//=================================================================
//                           ONCE
//=================================================================
#pragma mark - ONCE


/**
 GCD
 */
+ (instancetype) sharedInstance {
    static id __instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __instance = [[self alloc] init];
    });
    return __instance;
}

void fun() {
    NSLog(@"%@", [NSThread currentThread]);
}

- (void)onceOfPthread {
    __block pthread_once_t once = PTHREAD_ONCE_INIT;
    
    int i= 0;
    while (i > 5) {
        pthread_once(&once, fun);
        i++;
    }
   
}



@end
