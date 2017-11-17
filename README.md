![五花八门的🔐](https://user-gold-cdn.xitu.io/2017/11/14/15fb94c9bb65fa78?w=1006&h=650&f=png&s=1020048)


## 前言
iOS开发中由于各种第三方库的高度封装，对锁的使用很少，刚好之前面试中被问到的关于并发编程锁的问题，都是一知半解，于是决定整理一下关于iOS中锁的知识，为大家查缺补漏。


## 目录
### 第一部分： 什么是锁
### 第二部分： 锁的分类
### 第三部分： 性能对比
### 第四部分： 常见的死锁
### 第五部分： 总结(附[Demo](https://github.com/edsum/LockSets.git))

## 正文

### 一、什么是锁
在过去几十年并发研究领域的出版物中，锁总是扮演着坏人的角色，锁背负的指控包括引起死锁、锁封护（luyang注：lock convoying，多个同优先级的线程重复竞争同一把锁，此时大量虽然被唤醒而得不到锁的线程被迫进行调度切换，这种频繁的调度切换相当影响系统性能）、饥饿、不公平、data races以及其他许多并发带来的罪孽。有趣的是，在共享内存并行软件中真正承担重担的是——你猜对了——锁。

在计算机科学中，锁是一种同步机制，用于多线程环境中对资源访问的限制。你可以理解成它用于排除并发的一种策略。

```
	if (lock == 0) {
		lock = myPID;
	}
```
上面这段代码并不能保证这个任务有锁，因此它可以在同一时间被多个任务执行。这个时候就有可能多个任务都检测到lock是空闲的，因此两个或者多个任务都将尝试设置lock，而不知道其他的任务也在尝试设置lock。这个时候就会出问题了。再看看下面这段代码(Swift)：

```
	class Account {
    private(set) var val: Int = 0 //这里不可在其他方法修改，只能通过add/minus修改
    public func add(x: Int) {
        objc_sync_enter(self)
        defer {
            objc_sync_exit(self)
        }
        val += x
    }
    
    public func minus(x: Int) {
        objc_sync_enter(self)
        defer {
            objc_sync_exit(self)
        }
        val -= x;
    }
}
```

这样就能防止多个任务去修改val了。

### 二、锁的分类
锁根据不同的性质可以分成不同的类。

在WiKiPedia介绍中，一般的锁都是建议锁，也就四每个任务去访问公共资源的时候，都需要取得锁的资讯，再根据锁资讯来确定是否可以存取。若存取对应资讯，锁的状态会改变为锁定，因此其他线程不会访问该资源，当结束访问时，锁会释放，允许其他任务访问。有些系统有强制锁，若未经授权的锁访问锁定的资料，在访问时就会产生异常。

在iOS中，锁分为互斥锁、递归锁、信号量、条件锁、自旋锁、读写锁（一种特所的自旋锁）、分布式锁。

对于数据库的锁分类：

分类方式	     					| 分类
-------------------------- 	| -------------
按锁的粒度划分   					| 表级锁、行级锁、页级锁
按锁的级别划分	 					| 共享锁、排他锁
按加锁的方式划分   					| 自动锁、显示锁
按锁的使用方式划分					| 乐观锁、悲观锁
按操作划分 		  					| DML锁、DDL锁

这里就不再详细的介绍了，感兴趣的大家可以带[Wiki](https://www.wikipedia.org)
查阅[相关资料](http://www.yankay.com/并发编程之巧用锁/)。

#### 1、互斥锁

> 在编程中，引入对象互斥锁的概念，来保证共享数据操作的完整性。每个对象都对应于一个可称为“互斥锁”的标记，这个标记用来保证在任一时刻，只能有一个线程访问对象。

**1.1 @synchronized**

* @synchronized要一个参数，这个参数相当于信号量

```
// 用在防止多线程访问属性上比较多
- (void)setTestInt:(NSInteger)testInt {
	@synchronized (self) {
		_testInt = testInt;
	}
}
```

**1.2 NSLock**

* block及宏定义

```
// 定义block类型
typedef void(^MMBlock)(void);

// 定义获取全局队列方法
#define MM_GLOBAL_QUEUE(block) \
dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ \
    while (1) { \
        block();\
    }\
})
```

* 测试代码

```
NSLock *lock = [[NSLock alloc] init];
MMBlock block = ^{
	[lock lock];
	NSLog(@"执行操作");
	sleep(1);
	[lock unlock];
};
MM_GLOBAL_QUEUE(block);
```

**1.3 pthread**

> pthread除了创建互斥锁，还可以创建递归锁、读写锁、once等锁。稍后会介绍一下如何使用。如果想要深入学习pthread请查阅相关文档、资料单独学习。

* 静态初始化： ``pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER ``

* 动态初始化： ``pthread_mutex_init()`` 函数是以动态方式创建互斥锁的，参数 **attr** 指定了新建互斥锁的属性。如果参数 **attr** 为 **NULL** ,使用默认的属性，返回0代表初始化成功。这种方式可以初始化普通锁、递归锁(同 ** NSRecursiveLock** ), 初始化方式有些复杂。

* 此类初始化方法可设置锁的类型，``PTHREAD_MUTEX_ERRORCHECK `` 互斥锁不会检测死锁， ``PTHREAD_MUTEX_ERRORCHECK `` 互斥锁可提供错误检查， ``PTHREAD_MUTEX_RECURSIVE `` 递归锁， ``PTHREAD_PROCESS_DEFAULT `` 映射到 ``PTHREAD_PROCESS_NORMAL ``.

* 下面是我从[YYKit](https://github.com/ibireme/YYKit)copy下来的：

```
#import <pthread.h>

//YYKit
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
```

* 测试代码

```
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
```

* 输出结果：

```
 线程 2：加锁
 线程 0：加锁
 线程 1：加锁
 线程 2：睡眠 3 秒
```

```
 线程 2：加锁
 线程 0：加锁
 线程 1：加锁
 线程 2：睡眠 3 秒
 线程 2：解锁
 线程 0：睡眠 1 秒
 线程 2：加锁
```

```
 线程 2：加锁
 线程 0：加锁
 线程 1：加锁
 线程 2：睡眠 3 秒
 线程 2：解锁
 线程 0：睡眠 1 秒
 线程 2：加锁
 线程 0：解锁
 线程 1：睡眠 2 秒
 线程 0：加锁
```

#### 2、递归锁

> 同一个线程可以多次加锁，不会造成死锁

举个🌰：

```
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
```

这段代码是一个典型的死锁情况。在我们的线程中，RecursiveMethod是递归调用的。所有每次进入这个block时，都会去加一次锁，而从第二次开始，由于锁已经被使用了且没有解锁，所有它需要等待锁被解除，这样就导致了死锁，线程被阻塞住了。控制台会输出如下信息：

```
value = 5
*** -[NSLock lock]: deadlock ( '(null)')   *** Break on _NSLockError() to debug.
```

**2.1 NSRecursiveLock**

* 实现代码

```
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
```

* 输出结果(从输出结果可以看出并未发生死锁)：

```
加锁层数 3
加锁层数 2
加锁层数 1
加锁层数 3
加锁层数 2
加锁层数 1
加锁层数 3
加锁层数 2
```

**2.2 pthread**

* 代码实现

```
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
```

* 输出结果(同样，结果显示并未发生死锁)：

```
加锁层数 3
加锁层数 2
加锁层数 1
加锁层数 3
加锁层数 2
加锁层数 1
加锁层数 3
加锁层数 2
```

#### 3、信号量

> 信号量(Semaphore)，有时被称为信号灯，是在多线程环境下使用的一种设施，是可以用来保证两个或多个关键代码段不被并发调用。在进入一个关键代码段之前，线程必须获取一个信号量；一旦该关键代码段完成了，那么该线程必须释放信号量。其它想进入该关键代码段的线程必须等待直到第一个线程释放信号量 

**3.1 dispatch_semaphore_t**

* 同步实现

```
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

```

**3.2 pthread**

* 测试代码

```
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
```

#### 4、条件锁
**3.1 NSCodition**

> NSCondition 的对象实际上作为一个锁和一个线程检查器：锁主要为了当检测条件时保护数据源，执行条件引发的任务；线程检查器主要是根据条件决定是否继续运行线程，即线程是否被阻塞。

* NSCondition同样实现了NSLocking协议，所以它和NSLock一样，也有NSLocking协议的lock和unlock方法，可以当做NSLock来使用解决线程同步问题，用法完全一样。

```
- (void)getIamgeName:(NSMutableArray *)imageNames{
 	 NSCondition *lock = [[NSCondition alloc] init];
    NSString *imageName;
    [lock lock];
    if (imageNames.count>0) {
        imageName = [imageNames lastObject];
        [imageNames removeObject:imageName];
    }
    [lock unlock];
}
```

* 同时，NSCondition提供更高级的用法。wait和signal，和条件信号量类似。比如我们要监听imageNames数组的个数，当imageNames的个数大于0的时候就执行清空操作。思路是这样的，当imageNames个数大于0时执行清空操作，否则，wait等待执行清空操作。当imageNames个数增加的时候发生signal信号，让等待的线程唤醒继续执行。


* NSCondition和NSLock、@synchronized等是不同的是，NSCondition可以给每个线程分别加锁，加锁后不影响其他线程进入临界区。这是非常强大。
但是正是因为这种分别加锁的方式，NSCondition使用wait并使用加锁后并不能真正的解决资源的竞争。比如我们有个需求：不能让m<0。假设当前m=0,线程A要判断到m>0为假,执行等待；线程B执行了m=1操作，并唤醒线程A执行m-1操作的同时线程C判断到m>0，因为他们在不同的线程锁里面，同样判断为真也执行了m-1，这个时候线程A和线程C都会执行m-1,但是m=1，结果就会造成m=-1.

* 当我用数组做删除试验时，做增删操作并不是每次都会出现，大概3-4次后会出现。单纯的使用lock、unlock是没有问题的。

```
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
```

**3.2 NSCoditionLock**

* ``lock``不分条件，如果锁没被申请，直接执行代码

* ``unlock``不会清空条件，之后满足条件的锁还会执行

* ``unlockWithCondition: ``我的理解就是设置解锁条件(同一时刻只有一个条件，如果已经设置条件，相当于修改条件)

* ``lockWhenCondition:``满足特定条件,执行相应代码

* NSConditionLock同样实现了NSLocking协议，试验过程中发现性能很低。


* NSConditionLock也可以像NSCondition一样做多线程之间的任务等待调用，而且是线程安全的。

```
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
```

**3.3 POSIX Conditions**

* **POSIX**条件锁需要互斥锁和条件两项来实现，虽然看起来没有什么关系，但在运行时中，互斥锁将会与条件结合起来。线程将被一个互斥和条件结合的信号来唤醒。

* 首先初始化条件和互斥锁，当``ready_to_go``为**false**的时候，进入循环，然后线程将会被挂起，直到另一个线程将``ready_to_go``设置为true的时候，并且发送信号的时候，该线程才会被唤醒。

* 测试代码

```
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
```

#### 5、分布式锁

> 分布式锁是控制分布式系统之间同步访问共享资源的一种方式。在分布式系统中，常常需要协调他们的动作。如果不同的系统或是同一个系统的不同主机之间共享了一个或一组资源，那么访问这些资源的时候，往往需要互斥来防止彼此干扰来保证一致性，在这种情况下，便需要使用到分布式锁。

**5.1 NSDistributedLock**

* 处理多个进程或多个程序之间互斥问题。

* 一个获取锁的进程或程序在是否锁之前挂掉，锁不会被释放，可以通过breakLock方式解锁。

* iOS很少用到，暂不详细研究。

#### 6、读写锁

> 读写锁实际是一种特殊的自旋锁，它把对共享资源的访问者划分成读者和写者，读者只对共享资源进行读访问，写者则需要对共享资源进行写操作。这种锁相对于自旋锁而言，能提高并发性，因为在多处理器系统中，它允许同时有多个读者来访问共享资源，最大可能的读者数为实际的逻辑CPU数。写者是排他性的，一个读写锁同时只能有一个写者或多个读者（与CPU数相关），但不能同时既有读者又有写者。


**6.1 dispatch_barrier_async / dispatch_barrier_sync**

* 先来一个需求：假设我们原先有6个任务要执行，我们现在要插入一个任务0，这个任务0要在1、2、4都并发执行完之后才能执行，而4、5、6号任务要在这几个任务0结束后才允许并发。大致的意思如下图![](https://user-gold-cdn.xitu.io/2017/11/14/15fba7550dd91c62?w=864&h=514&f=png&s=37127)

* 直接上代码：

```
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
```

* 共同点：1、等待在它前面插入队列的任务先执行完；2、等待他们自己的任务执行完再执行后面的任务。

* 不同点：1、dispatch_barrier_sync将自己的任务插入到队列的时候，需要等待自己的任务结束之后才会继续插入被写在它后面的任务，然后执行它们；2、dispatch_barrier_async将自己的任务插入到队列之后，不会等待自己的任务结束，它会继续把后面的任务插入队列，然后等待自己的任务结束后才执行后面的任务。

**6.2 pthread**

* 与上述初始化方式类似，静态``THREAD_RWLOCK_INITIALIZER``、动态``pthread_rwlock_init()``、``pthread_rwlock_destroy``用来销毁该锁

```
#import <pthread.h>

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
```


#### 7、自旋锁

>  何谓自旋锁？它是为实现保护共享资源而提出一种锁机制。其实，自旋锁与互斥锁比较类似，它们都是为了解决对某项资源的互斥使用。无论是互斥锁，还是自旋锁，在任何时刻，最多只能有一个保持者，也就说，在任何时刻最多只能有一个执行单元获得锁。但是两者在调度机制上略有不同。对于互斥锁，如果资源已经被占用，资源申请者只能进入睡眠状态。但是自旋锁不会引起调用者睡眠，如果自旋锁已经被别的执行单元保持，调用者就一直循环在那里看是否该自旋锁的保持者已经释放了锁，"自旋"一词就是因此而得名。

**7.1 OSSpinLock**

* 使用方式

```
// 初始化
spinLock = OS_SPINKLOCK_INIT;
// 加锁
OSSpinLockLock(&spinLock);
// 解锁
OSSpinLockUnlock(&spinLock);
```

然而，[YYKit](https://github.com/ibireme/YYKit)作者的文章[不再安全的 OSSpinLock](https://blog.ibireme.com/2016/01/16/spinlock_is_unsafe_in_ios/?utm_source=tuicool&utm_medium=referral)有说到这个自旋锁存在优先级反转的问题。

**7.2 os_unfair_lock**

* 自旋锁已经不再安全，然后苹果又整出来个 os_unfair_lock_t ,这个锁解决了优先级反转的问题。

```
	os_unfair_lock_t unfairLock;
    unfairLock = &(OS_UNFAIR_LOCK_INIT);
    os_unfair_lock_lock(unfairLock);
    os_unfair_lock_unlock(unfairLock);
```

#### 8、atomic(property) set / get

> 利用``set`` / ``get`` 接口的属性实现原子操作，进而确保“被共享”的变量在多线程中读写安全，这已经是不能满足部分多线程同步要求。

* 在定义 ``property`` 的时候， 有``atomic`` 和 ``nonatomic``的属性修饰关键字。

* 对于``atomic``的属性，系统生成的 ``getter/setter`` 会保证 get、set 操作的完整性，不受其他线程影响。比如，线程 A 的 getter 方法运行到一半，线程 B 调用了 setter：那么线程 A 的 getter 还是能得到一个完好无损的对象。

* 而``nonatomic``就没有这个保证了。所以，``nonatomic``的速度要比``atomic``快。

-
[raw3d](https://stackoverflow.com/users/1405155/raw3d)

Atomic

* 是默认的
* 会保证 CPU 能在别的线程来访问这个属性之前，先执行完当前流程
* 速度不快，因为要保证操作整体完成


Non-Atomic

* 不是默认的
* 更快
* 线程不安全
* 如有两个线程访问同一个属性，会出现无法预料的结果


-

 [Vijayendra Tripathi](https://stackoverflow.com/users/661217/vijayendra-tripathi)
 
 * 假设有一个 atomic 的属性 "name"，如果线程 A 调``[self setName:@"A"]`，线程 B 调``[self setName:@"B"]``，线程 C 调``[self name]``，那么所有这些不同线程上的操作都将依次顺序执行——也就是说，如果一个线程正在执行 getter/setter，其他线程就得等待。因此，属性 name 是读/写安全的。

* 但是，如果有另一个线程 D 同时在调``[name release]``，那可能就会crash，因为 release 不受 getter/setter 操作的限制。也就是说，这个属性只能说是读/写安全的，但并不是线程安全的，因为别的线程还能进行读写之外的其他操作。线程安全需要开发者自己来保证。

* 如果 name 属性是 nonatomic 的，那么上面例子里的所有线程 A、B、C、D 都可以同时执行，可能导致无法预料的结果。如果是 atomic 的，那么 A、B、C 会串行，而 D 还是并行的。

-
* 简单来说，就是atomic会加一个锁来保障线程安全，并且引用计数会+1，来向调用者保证这个对象会一直存在。假如不这样做，如果另一个线程调setter，可能会出现线程竞态，导致引用计数降到0，原来那个对象就是否了。

#### 9、ONCE

**9.1 GCD**

* 多用于创建单例。

```
+ (instancetype) sharedInstance {
	static id __instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		__instance = [[self alloc] init];
	});
	return __instance;
}
```

**9.2 pthread**

* 废话不多说，直接上代码

```
// 定义方法
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
```

### 三、性能对比

**基础表现-所操作耗时**

![](https://user-gold-cdn.xitu.io/2017/11/14/15fba75542bd8ae1?w=1024&h=499&f=png&s=237620)

上图是常规的锁操作性能测试(iOS7.0SDK，iPhone6模拟器，Yosemite 10.10.5)，垂直方向表示耗时，单位是秒，总耗时越小越好，水平方向表示不同类型锁的锁操作，具体又分为两部分，左边的常规lock操作(比如NSLock)或者读read操作(比如[ANReadWriteLock](https://github.com/SpringOx/ANLock))，右边则是写write操作，图上仅有[ANReadWriteLock](https://github.com/SpringOx/ANLock)和[ANRecursiveRWLock](https://github.com/SpringOx/ANLock)支持，其它不支持的则默认为0，图上看出，单从性能表现，原子操作是表现最佳的(0.057412秒)，@synchronized则是最耗时的(1.753565秒) (测试代码) 。

**多线程锁删除数组性能测试**

* 模拟器环境：i5 2.6GH+8G 内存，xcode 7.2.1 (7C1002)+iPhone6SP(9.2)

![](https://user-gold-cdn.xitu.io/2017/11/14/15fb94c9b4a9b1cb?w=1212&h=518&f=png&s=61062)


* 真机环境：xcode 7.2.1 (7C1002)+iPhone6(国行)

![](https://user-gold-cdn.xitu.io/2017/11/14/15fb94c9b75aeff5?w=1216&h=513&f=png&s=63218)

* 通过测试发现模拟器和真机的区别还是很大的，模拟器上明显的阶梯感，真机就没有，模拟器上NSConditionLock的性能非常差，我没有把它的参数加在表格上，不然其他的就看不到了。不过真机上面性能还好。

* 这些性能测试只是一个参考，没必要非要去在意这些，毕竟前端的编程一般线程要求没那么高，可以从其他的地方优化。线程安全中注意避坑，另外选择自己喜欢的方式，这样你可以研究的更深入，使用的更熟练。

**声明**： 测试结果仅仅代表一个参考，因为各种因素的影响，并没有那么准确。


**综合比较**

![](https://user-gold-cdn.xitu.io/2017/11/14/15fba7551ab4ed7a?w=1060&h=684&f=png&s=71662)

可以看到除了 **OSSpinLock** 外，**dispatch_semaphore** 和 **pthread_mutex** 性能是最高的。有消息称，苹果在新的系统中已经优化了 **pthread_mutex** 的性能，所有它看上去和 **dispatch_semaphore** 差距并没有那么大了。


### 四、常见的死锁

**首先要明确几个概念**
#### 1.串行与并行

在使用GCD的时候，我们会把需要处理的任务放到Block中，然后将任务追加到相应的队列里面，这个队列，叫做 **Dispatch Queue**。然而，存在于两种**Dispatch Queue**，一种是要等待上一个任务执行完，再执行下一个的**Serial Dispatch Queue**，这叫做串行队列；另一种，则是不需要上一个任务执行完，就能执行下一个的**ConcurrentDispatch Queue**，叫做并行队列。这两种，均遵循**FIFO**原则。

>举一个简单的例子，在三个任务中输出1、2、3，串行队列输出是有序的1、2、3，但是并行队列的先后顺序就不一定了。

虽然可以同时多个任务的处理，但是并行队列的处理量，还是要根据当前系统状态来。如果当前系统状态最多处理2个任务，那么1、2会排在前面，3什么时候操作，就看1或者2谁先完成，然后3接在后面。

串行和并行就简单说到这里，关于它们的技术点其实还有很多，可以自行了解。

#### 2.同步与异步

串行与并行针对的是队列，而同步与异步，针对的则是线程。最大的区别在于，同步线程要阻塞当前线程，必须要等待同步线程中的任务执行完，返回以后，才能继续执行下一个任务；而异步线程则是不用等待。

#### 3.GCD API

GCD API很多，这里仅介绍本文用到的。

- 1. 系统提供的两个队列

```
// 全局队列，也是一个并行队列
dispatch_get_global_queue
// 主队列，在主线程中运行，因为主线程只有一个，所有这是一个串行队列
dispatch_get_main_queue
```

- 2. 除此之外，还可以自己生成队列

```
// 从DISPATCH_QUQUE_SERIAL看出，这是串行队列
dispatch_queue_create("com.demo.serialQueue", DISPATCH_QUEUE_SERIAL)
// 同理，这是一个并行队列
dispatch_queue_create("com.demo.concurrentQueue", DISPATCH_QUEUE_CONCURRENT) 
```

- 3. 接下来是同步与异步线程的创造

```
dispatch_sync(..., ^(block)) // 同步线程
dispatch_async(..., ^(block)) // 异步线程
```

#### 案例分析
##### 案例一

```
NSLog(@"1"); // 任务1
dispatch_sync(dispatch_get_main_queue(), ^{
    NSLog(@"2"); // 任务2
});
NSLog(@"3"); // 任务3
```

* 结果，控制台输出：

```
1
```

**分析**

- 1. dispatch_sync表示一个同步线程；
- 2. dispatch_get_main_queue表示运行在主线程中的主队列；
- 3. 任务2是同步线程的任务。

首先执行任务1，这是肯定没问题的，只是接下来，程序遇到了同步线程，那么它会进入等待，等待任务2执行完，然后执行任务3。但这是队列，有任务来，当然会将任务加到队尾，然后遵循FIFO原则执行任务。那么，现在任务2就会被加到最后，任务3排在了任务2前面，问题来了：

> 任务3要等任务2执行完才能执行，任务2由排在任务3后面，意味着任务2要在任务3执行完才能执行，所以他们进入了互相等待的局面。【既然这样，那干脆就卡在这里吧】这就是死锁。

![](https://user-gold-cdn.xitu.io/2017/11/14/15fba754f82f3742?w=690&h=511&f=jpeg&s=53499)

##### 案例二

```
NSLog(@"1"); // 任务1
dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    NSLog(@"2"); // 任务2
});
NSLog(@"3"); // 任务3
```

* 结果，控制台输出：

```
1
2
3
```

**分析**

首先执行任务1，接下来会遇到一个同步线程，程序会进入等待。等待任务2执行完成以后，才能继续执行任务3。从dispatch_get_global_queue可以看出，任务2被加入到了全局的并行队列中，当并行队列执行完任务2以后，返回到主队列，继续执行任务3。

![](https://user-gold-cdn.xitu.io/2017/11/14/15fba754f839489f?w=690&h=608&f=jpeg&s=74937)

##### 案例三

``` 
dispatch_queue_t queue = dispatch_queue_create("com.demo.serialQueue", DISPATCH_QUEUE_SERIAL);
NSLog(@"1"); // 任务1
dispatch_async(queue, ^{
    NSLog(@"2"); // 任务2
    dispatch_sync(queue, ^{  
        NSLog(@"3"); // 任务3
    });
    NSLog(@"4"); // 任务4
});
NSLog(@"5"); // 任务5
```

* 结果，控制台输出：

```
1
5
2
// 5和2的顺序不一定
```

**分析**

这个案例没有使用系统提供的串行或并行队列，而是自己通过dispatch_queue_create函数创建了一个DISPATCH_QUEUE_SERIAL的串行队列。

- 1.  执行任务1；
- 2. 遇到异步线程，将【任务2、同步线程、任务4】加入串行队列中。因为是异步线程，所以在主线程中的任务5不必等待异步线程中的所有任务完成；
- 3. 因为任务5不必等待，所以2和5的输出顺序不能确定；
- 4. 任务2执行完以后，遇到同步线程，这时，将任务3加入串行队列；
- 5. 又因为任务4比任务3早加入串行队列，所以，任务3要等待任务4完成以后，才能执行。但是任务3所在的同步线程会阻塞，所以任务4必须等任务3执行完以后再执行。这就又陷入了无限的等待中，造成死锁。

![](https://user-gold-cdn.xitu.io/2017/11/14/15fba7553abfc37d?w=690&h=447&f=jpeg&s=75075)

##### 案例四

```
NSLog(@"1"); // 任务1
dispatch_async(dispatch_get_global_queue(0, 0), ^{
    NSLog(@"2"); // 任务2
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSLog(@"3"); // 任务3
    });
    NSLog(@"4"); // 任务4
});
NSLog(@"5"); // 任务5
```

* 结果，控制台输出：

```
1
2
5
3
4
// 5和2的顺序不一定
```

**分析**

首先，将【任务1、异步线程、任务5】加入Main Queue中，异步线程中的任务是：【任务2、同步线程、任务4】。

所以，先执行任务1，然后将异步线程中的任务加入到Global Queue中，因为异步线程，所以任务5不用等待，结果就是2和5的输出顺序不一定。

然后再看异步线程中的任务执行顺序。任务2执行完以后，遇到同步线程。将同步线程中的任务加入到Main Queue中，这时加入的任务3在任务5的后面。

当任务3执行完以后，没有了阻塞，程序继续执行任务4。

从以上的分析来看，得到的几个结果：1最先执行；2和5顺序不一定；4一定在3后面。

![](https://user-gold-cdn.xitu.io/2017/11/14/15fba754f672280b?w=690&h=544&f=jpeg&s=87753)

##### 案例五

```
dispatch_async(dispatch_get_global_queue(0, 0), ^{
    NSLog(@"1"); // 任务1
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSLog(@"2"); // 任务2
    });
    NSLog(@"3"); // 任务3
});
NSLog(@"4"); // 任务4
while (1) {
}
NSLog(@"5"); // 任务5
```

* 结果，控制台输出：

```
1
4
// 1和4的顺序不一定
```

**分析**

和上面几个案例的分析类似，先来看看都有哪些任务加入了Main Queue：【异步线程、任务4、死循环、任务5】。

在加入到Global Queue异步线程中的任务有：【任务1、同步线程、任务3】。

第一个就是异步线程，任务4不用等待，所以结果任务1和任务4顺序不一定。

任务4完成后，程序进入死循环，Main Queue阻塞。但是加入到Global Queue的异步线程不受影响，继续执行任务1后面的同步线程。

同步线程中，将任务2加入到了主线程，并且，任务3等待任务2完成以后才能执行。这时的主线程，已经被死循环阻塞了。所以任务2无法执行，当然任务3也无法执行，在死循环后的任务5也不会执行。

最终，只能得到1和4顺序不定的结果。

![](https://user-gold-cdn.xitu.io/2017/11/14/15fba754f6d63611?w=690&h=475&f=jpeg&s=66582)

### 五、总结

- 1. 总的来看，推荐pthread_mutex作为实际项目的首选方案；
- 2. 对于耗时较大又易冲突的读操作，可以使用读写锁代替pthread_mutex；
- 3. 如果确认仅有set/get的访问操作，可以选用原子操作属性；
- 4. 对于性能要求苛刻，可以考虑使用OSSpinLock，需要确保加锁片段的耗时足够小；
- 5. 条件锁基本上使用面向对象的NSCondition和NSConditionLock即可；
- 6. @synchronized则适用于低频场景如初始化或者紧急修复使用；

苹果为多线程、共享内存提供了多种同步解决方案(锁),对于这些方案的比较，大都讨论了锁的用法以及锁操作的开销。个人认为最优秀的选用还是看应用场景，高频接口VS低频接口、有限冲突VS激烈竞争、代码片段耗时的长短，都是选择的重要依据，选择适用于当前应用场景的方案才是王道。

最后，由于时间匆促，如果有错误或者不足的地方请指正，最后附上[Demo](https://github.com/edsum/LockSets.git)所有代码的集合,下面是我的**github**和**博客**。

联系方式：ed_sun0129@163.com

> [github](https://github.com/edsum)
> 
> [blog](https://edsum.github.io)


### 参考文档
- [Threading Programming Guide](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/Multithreading/Introduction/Introduction.html#//apple_ref/doc/uid/10000057i)
- [不再安全的 OSSpinLock](https://blog.ibireme.com/2016/01/16/spinlock_is_unsafe_in_ios/)
- [iOS 锁的简单实现与总结](http://www.jianshu.com/p/a33959324cc7)
- [iOS中的各种锁](http://www.jianshu.com/p/6c8bf19eb10d)
- [NSRecursiveLock递归锁的使用](http://www.cocoachina.com/ios/20150513/11808.html)
- [iOS GCD死锁](http://www.brighttj.com/ios/ios-gcd-deadlock.html)
