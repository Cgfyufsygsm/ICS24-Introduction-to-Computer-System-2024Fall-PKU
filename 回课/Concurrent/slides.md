---
# You can also start simply with 'default'
theme: seriph
# random image from a curated Unsplash collection by Anthony
# like them? see https://unsplash.com/collections/94734566/slidev
background: bg.jpg
# some information about your slides (markdown enabled)
title: "Review: CONC"
info: 
# apply unocss classes to the current slide
class: text-center
# https://sli.dev/features/drawing
drawings:
  persist: false
# slide transition: https://sli.dev/guide/animations.html#slide-transitions
transition: fade-out
# enable MDC Syntax: https://sli.dev/features/mdc
mdc: true
fonts:
  # sans: "华文中宋"
  # local: "华文中宋"
  sans: Consolas
  local: Consolas
lineNumbers: true
---

# Review: Concurrent
## (CS: APP Ch. 12.1-12.3)

Taoyu Yang, EECS, PKU


<!--
The last comment block of each slide will be treated as slide notes. It will be visible and editable in Presenter Mode along with the slide. [Read more in the docs](https://sli.dev/guide/syntax.html#notes)
-->

---
transition: fade-out
---

# Contents

Concurrent Programming

- Concurrency
  - Concept
  - Potential Problems
- Approaches for writing concurrent programs:
  - Process-Based
  - I/O-multiplexing-Based
  - Thread-Based

---

# Concurrency

并发

Firstly we need to clarify these two concepts:

- **Concurrency**（并发）: logical control flows are **concurrent** if they **overlap in time**.
- **Parallelism**（并行）: executing multiple tasks **at the same time**, typically on *multiple processors or cores*.

Thus far, we have treated concurrency mainly as a mechanism that the operating system **kernel** uses to run multiple application programs.

It can play an important role in application programs as well. e.g.: Linux signal handlers allow applications to respond to asynchronous events...

---

# Problems that may occur:

Classical ones

However, since the human brain processes thoughts **sequentially**, writing concurrent programs is not an easy task. For instance, we might face such classical issues:

- **Races**: outcome depends on arbitrary scheduling decisions elsewhere in the system
  - Example: the last seat
- **Deadlock**: improper resource allocation prevents forward progress
  - Example: why you shouldn't use `printf` in a signal handler funcion. 
- **Starvation**: external events and/or system scheduling decisions can prevent sub-task progress

It may be hard, but it can be useful and **more and more necessary**! e.g. the *echo server*.

---

# Three Basic Approaches

to implement application-level concurrency

- **Process-Based**
  - multiple processes
- **I/O multiplexing-Based**
  - single processes
  - state machines
- **Thread-Based**
  - single process, multiple **threads**
  - hybrid of previous ones

We will discuss how to implement a concurrent version of the iterative echo server from 11.4.9 using these three techniques.

---

# Process-Based

we are familiar with

- `fork`, `exec`, `waitpit`...
- **Kernel automatically** interleaves multiple logical flow, but context switching is **slow**!
- Each flow has its own **private address space**, making it hard to share state information.
  - To share information, they must use explicit **IPC** mechanisms. **slow**!


![](/process.png){.h-60.m-auto}

---
layout: two-cols
layoutClass: gap-12
---

# Process-Based

implementation


Firstly, since it's expected to run for a long time, we must include a SIGCHLD handler that reaps zombie children.

> After `fork`, parent and child process share same file table but have their own *fd*s respectively

- For child process, it must close `listenfd`
- For both of them (especially **parent**), they must close `connfd`. Otherwise the file table entry which `connfd` points to will never be released, causing memory leak



::right::

```c{all|1-4|16|18,22}
void sigchld_handler(int sig) {
  while (waitpid(-1, 0, WNOHANG) > 0);
  return;
}

int main(int argc, char **argv) {
  ...

  Signal(SIGCHLD, sigchld_handler);
  listenfd = Open_listenfd(argv[1]);
  while (1) {
    clientlen = sizeof(struct sockaddr_storage);
    connfd = Accept(listenfd, 
             (SA *)&clientaddr, &clientlen);
    if (Fork() == 0) {
      Close(listenfd); /* Child closes its listening socket */
      echo(connfd); /* Child services client */ // line:conc:echoserverp:echofun
      Close(connfd);
          /* Child closes connection with client */ // line:conc:echoserverp:childclose
      exit(0);                                      /* Child exits */
    }
    Close(connfd);
        /* Parent closes connected socket (important!) */ // line:conc:echoserverp:parentclose
  }
}
```

---
layout: two-cols
layoutClass: gap-12
---

# Process-Based

implementation


> **Practice Problem 12.1**
> 
> Why can the child process still connect with the client after the parent closes `connfd` in line 22?

<div v-click>

Key: the kernel won't close a file until its `refcnt` becomes 0 in the *file table*.

</div>

> **Practice Problem 12.2**
>
> If we were to delete line 18, the code would still be correct, in the sense that there would be no memory leak. Why?

<div v-click>

Key: when a process ternimates, the kernel will close all of its opened file descriptors.

</div>

::right::

```c{18,22}
void sigchld_handler(int sig) {
  while (waitpid(-1, 0, WNOHANG) > 0);
  return;
}

int main(int argc, char **argv) {
  ...

  Signal(SIGCHLD, sigchld_handler);
  listenfd = Open_listenfd(argv[1]);
  while (1) {
    clientlen = sizeof(struct sockaddr_storage);
    connfd = Accept(listenfd, 
             (SA *)&clientaddr, &clientlen);
    if (Fork() == 0) {
      Close(listenfd); /* Child closes its listening socket */
      echo(connfd); /* Child services client */ // line:conc:echoserverp:echofun
      Close(connfd);
          /* Child closes connection with client */ // line:conc:echoserverp:childclose
      exit(0);                                      /* Child exits */
    }
    Close(connfd);
        /* Parent closes connected socket (important!) */ // line:conc:echoserverp:parentclose
  }
}
```
---

# I/O multiplexing

event-based

Server maintains a set of active connections

Repeat:

- Determine which descriptors (`connfd`s or `listenfd`) have pending inputs
  - e.g., using `select` funcion
  - arrival of pending input is an *event*
- If `listenfd` has input, `accept` the connection
- Serve all `connfd`s with pending inputs

---

# `select` function

`#include <sys/select.h>`

```c
int select(int n, fd_set *readfds, fd_set *writefds, fd_set *exceptfds, struct timeval *timeout);

FD_ZERO(fd_set *fdset);
FD_CLR(int fd, fd_set *fdset);
FD_SET(int fd, fd_set *fdset);
FD_ISSET(int fd, fd_set *fdset);
```

We only discuss one scenario: waiting for a set of descriptors to be ready for reading. In this case the last three `fd_set*`s will be set to be `NULL`.

A `fd_set` is a **descriptor set**, which is a *bit vector*. The `n` we pass in means the cardinality of the read set.

`select` will **block** until a descriptor is ready, then modify the read set and returns nonzero count of ready descriptors, −1 on error.

---
layout: two-cols
layoutClass: gap-12
---


# I/O multiplexing

implementation

The general idea is to model logical flows as *state machines*. 

The server uses `select` to detect input events. As each connected descriptor becomes ready for reading, the server executes the transition for the corresponding state machine

![](/state-machine.png){.h-50.w-auto}

::right::

```c {*|3-12|21-48|31|52-63|31|32-48|38-44|43|67-89|43|45-46|93-119|32-48}{maxHeight:'500px'}
#include "csapp.h"

typedef struct {
  /* Represents a pool of connected descriptors */ // line:conc:echoservers:beginpool
  int maxfd;                   /* Largest descriptor in read_set */
  fd_set read_set;             /* Set of all active descriptors */
  fd_set ready_set;            /* Subset of descriptors ready for reading  */
  int nready;                  /* Number of ready descriptors from select */
  int maxi;                    /* Highwater index into client array */
  int clientfd[FD_SETSIZE];    /* Set of active descriptors */
  rio_t clientrio[FD_SETSIZE]; /* Set of active read buffers */
} pool;                        // line:conc:echoservers:endpool
/* $end echoserversmain */
void init_pool(int listenfd, pool *p);
void add_client(int connfd, pool *p);
void check_clients(pool *p);
/* $begin echoserversmain */

int byte_cnt = 0; /* Counts total bytes received by server */

int main(int argc, char **argv) {
  int listenfd, connfd;
  socklen_t clientlen;
  struct sockaddr_storage clientaddr;
  static pool pool;
  if (argc != 2) {
    fprintf(stderr, "usage: %s <port>\n", argv[0]);
    exit(0);
  }
  listenfd = Open_listenfd(argv[1]);
  init_pool(listenfd, &pool); // line:conc:echoservers:initpool
  while (1) {
    /* Wait for listening/connected descriptor(s) to become ready */
    pool.ready_set = pool.read_set;
    pool.nready = Select(pool.maxfd + 1, 
       &pool.ready_set, NULL, NULL, NULL);
    /* If listening descriptor ready, add new client to pool */
    if (FD_ISSET(listenfd,
                 &pool.ready_set)) { // line:conc:echoservers:listenfdready
      clientlen = sizeof(struct sockaddr_storage);
      connfd = Accept(listenfd, (SA*)&clientaddr,
                      &clientlen); // line:conc:echoservers:accept
      add_client(connfd, &pool);   // line:conc:echoservers:addclient
    }
    /* Echo a text line from each ready connected descriptor */
    check_clients(&pool); // line:conc:echoservers:checkclients
  }
}
/* $end echoserversmain */

/* $begin init_pool */
void init_pool(int listenfd, pool *p) {
  /* Initially, there are no connected descriptors */
  int i;
  p->maxi = -1; // line:conc:echoservers:beginempty
  for (i = 0; i < FD_SETSIZE; i++)
    p->clientfd[i] = -1; // line:conc:echoservers:endempty

  /* Initially, listenfd is only member of select read set */
  p->maxfd = listenfd; // line:conc:echoservers:begininit
  FD_ZERO(&p->read_set);
  FD_SET(listenfd, &p->read_set); // line:conc:echoservers:endinit
}
/* $end init_pool */

/* $begin add_client */
void add_client(int connfd, pool *p) {
  int i;
  p->nready--;
  for (i = 0; i < FD_SETSIZE; i++) /* Find an available slot */
    if (p->clientfd[i] < 0) {
      /* Add connected descriptor to the pool */
      p->clientfd[i] = connfd; // line:conc:echoservers:beginaddclient
      Rio_readinitb(&p->clientrio[i],
                    connfd); // line:conc:echoservers:endaddclient

      /* Add the descriptor to descriptor set */
      FD_SET(connfd, &p->read_set); // line:conc:echoservers:addconnfd

      /* Update max descriptor and pool highwater mark */
      if (connfd > p->maxfd) // line:conc:echoservers:beginmaxfd
        p->maxfd = connfd;   // line:conc:echoservers:endmaxfd
      if (i > p->maxi)       // line:conc:echoservers:beginmaxi
        p->maxi = i;         // line:conc:echoservers:endmaxi
      break;
    }
  if (i == FD_SETSIZE) /* Couldn't find an empty slot */
    app_error("add_client error: Too many clients");
}
/* $end add_client */

/* $begin check_clients */
void check_clients(pool *p) {
  int i, connfd, n;
  char buf[MAXLINE];
  rio_t rio;

  for (i = 0; (i <= p->maxi) && (p->nready > 0); i++) {
    connfd = p->clientfd[i];
    rio = p->clientrio[i];

    /* If the descriptor is ready, echo a text line from it */
    if ((connfd > 0) && (FD_ISSET(connfd, &p->ready_set))) {
      p->nready--;
      if ((n = Rio_readlineb(&rio, buf, MAXLINE)) != 0) {
        byte_cnt += n; // line:conc:echoservers:beginecho
        printf("Server received %d (%d total) bytes on fd %d\n", n, byte_cnt,
               connfd);
        Rio_writen(connfd, buf, n); // line:conc:echoservers:endecho
      }

      /* EOF detected, remove descriptor from pool */
      else {
        Close(connfd);                // line:conc:echoservers:closeconnfd
        FD_CLR(connfd, &p->read_set); // line:conc:echoservers:beginremove
        p->clientfd[i] = -1;          // line:conc:echoservers:endremove
      }
    }
  }
}
```

---
layout: two-cols
layoutClass: gap-12
---

# I/O multiplexing

pros and cons


## Pros

- Event-driven designs give programmers more control over the behavior of their programs than process-based designs.
  > such as specifing the priority of certain clients, which cannot be implemented in a process-based program
- Single process: easy to share data between flows
  - Easier to debug
  - More efficient since no need to switch the context

::right::

<br><br>

## Cons

- Higher coding complexity: as you can see
- The complexity increases as the granularity of the concurrency decreases. 
  > By granularity, we mean the number of instructions that each logical flow executes per time slice. For instance, in our example concurrent server, the granularity of concurrency is the number of instructions required to read an entire text line.
- Cannot fully utilize multi-core processors

---

# Thread

hybrid

- Definition: A ***thread*** is a logical flow that runs in the context of a process.
- Each thread has its own *thread context*, including a unique integer *thread ID* (TID), stack, stack pointer, program counter, general-purpose registers, and condition codes. 
  > but its stack (for local variables) is not protected from other threads
- Multiple threads run in the context of a single process, and thus they **share the entire contents of the process virtual address space**, making it convenient to share information between them.

---
layout: two-cols
---

# Thread Execution Model

main thread and peer threads

- Each process begins life as a single thread called the **main thread**.
- A thread is called a **peer thread** if it is created by another thread in the same process. Threads associated with a process form a **pool of peers**.
- Unlike processes, there's no parent-child like hierarchical relationship between threads.
- The main thread is distinguished from others only because it's the first thread to run in the process.

::right::

![](/thread.png)

---

# POSIX Threads Interface

Pthreads

Posix threads (Pthreads) is a standard interface for manipulating threads from C programs. Pthreads defines about 60 functions that allow programs to create, kill, and reap threads, to share data safely with peer threads, and to notify peers about changes in the system state.

```c
#include "csapp.h"
void *thread(void *vargp);                    //line:conc:hello:prototype

int main() {
    pthread_t tid;                            //line:conc:hello:tid
    Pthread_create(&tid, NULL, thread, NULL); //line:conc:hello:create
    Pthread_join(tid, NULL);                  //line:conc:hello:join
    exit(0);                                  //line:conc:hello:exit
}

void *thread(void *vargp) {
    printf("Hello, world!\n");                 
    return NULL;                               //line:conc:hello:return
}
```

---
layout: two-cols
layoutClass: gap-12
---

# POSIX API

pthread

- The code and local data for a thread are encapsulated in a **thread routine**.
- Creating threads and determining one's own TID.
- Terminating:
  - *Implicitly* when its top-level thread routine returns.
  - *Explicitly* by calling `pthread_exit`, returns value via `thread_return`.
  - A process terminates when a thread calls `exit()`, thus all threads associated will ternimate.

::right::

<br><br>

```c{*|2-5|7|9-10}
#include <pthread.h>
typedef void *(func)(void *);

int pthread_create(pthread_t *tid, 
    pthread_attr_t *attr, func *f, void *arg);

pthread_t pthread_self(void);

void pthread_exit(void *thread_return);
int pthread_cancel(pthread_t tid);

int pthread_join(pthread_t tid, 
    void **thread_return);

int pthread_detach(pthread_t tid);

pthread_once_t once_control = PTHREAD_ONCE_INIT;
int pthread_once(pthread_once_t *once_control,
    void (*init_routine)(void));
```

---
layout: two-cols
layoutClass: gap-12
---

# POSIX API

pthread

- A thread can terminate another by calling `pthread_cancel(tid)`.
- The `pthread_join` function blocks until thread `tid` terminates, assigns the generic (void \*) pointer returned by the thread routine to the location pointed to by thread_return, and then *reaps* any memory resources held by the terminated thread.
  - It can only wait for a *specific* thread to ternimate, unlike `wait`.

::right::

<br><br>

```c{10|12-13}
#include <pthread.h>
typedef void *(func)(void *);

int pthread_create(pthread_t *tid, 
    pthread_attr_t *attr, func *f, void *arg);

pthread_t pthread_self(void);

void pthread_exit(void *thread_return);
int pthread_cancel(pthread_t tid);

int pthread_join(pthread_t tid, 
    void **thread_return);

int pthread_detach(pthread_t tid);

pthread_once_t once_control = PTHREAD_ONCE_INIT;
int pthread_once(pthread_once_t *once_control,
    void (*init_routine)(void));
```

---
layout: two-cols
layoutClass: gap-12
---

# POSIX API

detached?

- A thread is either *joinable* or *detached*.
- A joinable thread can be reaped and killed by others. Its memory is not freed until it is reaped.
- A detached thread cannot be reaped or killed by others. Its memory is freed automatically when it terminates.
- Either explicitly reap a thread, or call `pthread_detach` in order to avoid memory leak.

::right::

<br><br>

```c{15}
#include <pthread.h>
typedef void *(func)(void *);

int pthread_create(pthread_t *tid, 
    pthread_attr_t *attr, func *f, void *arg);

pthread_t pthread_self(void);

void pthread_exit(void *thread_return);
int pthread_cancel(pthread_t tid);

int pthread_join(pthread_t tid, 
    void **thread_return);

int pthread_detach(pthread_t tid);

pthread_once_t once_control = PTHREAD_ONCE_INIT;
int pthread_once(pthread_once_t *once_control,
    void (*init_routine)(void));
```

---
layout: two-cols
layoutClass: gap-12
---

# Thread-Based

implementation

````md magic-move
```c{*|13-16}{startLine:6}
int main(int argc, char **argv) {
  int listenfd, *connfdp;
  socklen_t clientlen;
  struct sockaddr_storage clientaddr;
  pthread_t tid;
  if (argc != 2) {
    fprintf(stderr, "usage: %s <port>\n", argv[0]);
    exit(0);
  }
  listenfd = Open_listenfd(argv[1]);
  while (1) {
    clientlen = sizeof(struct sockaddr_storage);
    /* Why do we use malloc here? */
    connfdp = Malloc(sizeof(int));
    *connfdp = Accept(listenfd, (SA *)&clientaddr,
                      &clientlen);
    Pthread_create(&tid, NULL, thread, connfdp);
  }
}
```
```c{*}{startLine:6}
int main(int argc, char **argv) {
  int listenfd, *connfdp;
  socklen_t clientlen;
  struct sockaddr_storage clientaddr;
  pthread_t tid;
  if (argc != 2) {
    fprintf(stderr, "usage: %s <port>\n", argv[0]);
    exit(0);
  }
  listenfd = Open_listenfd(argv[1]);
  while (1) {
    clientlen = sizeof(struct sockaddr_storage);
    /* What will happen in this case? */
    int connfd;
    connfd = Accept(listenfd, (SA *)&clientaddr,
                      &clientlen);
    Pthread_create(&tid, NULL, thread, &connfd);
  }
}
```
````

::right::

<br><br>

```c
#include "csapp.h"

void echo(int connfd);
void *thread(void *vargp);
```

Thread routine:

```c{*|30}{startLine:28}
void *thread(void *vargp) {
  int connfd = *((int *)vargp);
  Pthread_detach(pthread_self());
  Free(vargp);                    
  echo(connfd);
  Close(connfd);
  return NULL;
}
```

---

# Thread-Based

Summary

- Some advantages:
  - Easy to share data structures between logical flows
    - Since all threads share the same address space
  - More efficient than process
    - Context switching is faster

- However, Unintentional sharing can introduce subtle and hard-to-reproduce errors
  - hard to debug
  - The ease with which data can be shared is a double-edged sword.

---
layout: two-cols
layoutClass: gap-12
---

# Exercises

2013 Final

19、在 Pthread 线程包使用中，下列代码输出正确的是

```c
void *th_f(void *arg) {
  printf("Hello World");
  pthread_exit(0);
}

int main(void) {
  pthread_t tid;
  int st;
  st = pthread_create(&tid, NULL, th_f, NULL);
  if (st < 0) {
    printf("Oops, I can not create thread\n");
    exit(-1);
  }
  sleep(1);
  exit(0);
}
```

::right::

<br><br>

A. `Oops, I can not create thread`

B. 
   ```
   Hello World
   Oops, I can not create thread
   ```
C. `Hello World`

D. 不输出任何信息

<div v-click>

<br>

Answer: C

</div>

---

# Exercises

2018 Final

14、 下列关于进程与线程的描述中，哪一个是不正确的?

A. 一个进程可以包含多个线程

B. 进程中的各个线程共享进程的代码、数据、堆和栈

C. 进程中的各个线程拥有自己的线程上下文

D. 线程的上下文切换比进程的上下文切换快

<br>

<div v-click>

Answer: B

线程之间不共享栈。

</div>

---
layout: two-cols
layoutClass: gap-12
---

# Exercises

2020 Final

24、以下程序在输出有限行之后就终止了，请问最有可能的原因是（假定所有函数都正常执行）

```c
#include "csapp.h"

void *thread(void *dummy) {
  while (1) {
    printf("hello, world!\n");
    Sleep(1);
  }
}

int main() {
  pthread_t tid;
  Pthread_create(&tid, NULL, thread, NULL);
  Sleep(3);
}
```

::right::

<br><br>

A. 主线程结束必然引发所有对等线程结束

B. 主线程结束时调用了 `_exit` 导致进程结束

C. 主线程结束后，内核发送 `SIGKILL` 杀死进程

D. 主线程结束后，内核观察到对等线程运行时间过长，将其杀死

<br>

<div v-click>

Answer: B

> main 函数的 return 会触发 exit 调用，或者通过 _exit（如果没有正常调用 exit）来终止程序。

</div>

---

# Exercises

2022 Final

20、下列关于 C 语言中进程模型和线程模型的说法中，错误的是：

A. 每个线程都有它自己独立的线程上下文，包括线程 ID、程序计数器、条件码、通用目的寄存器值等。

B. 每个线程都有自己独立的线程栈，任何线程都不能访问其他对等线程的栈空间。

C. 不同进程之间的虚拟地址空间是独立的，但同一个进程的不同线程共享同一个虚拟地址空间

D. 一个线程的上下文比一个进程的上下文小得多，因此线程上下文切换要比进程上下文切换快得多

<br>

<div v-click>

Answer: B

</div>

---

# Summary

approaches to concurrency

- Process-based
  - Hard to share resources: Easy to avoid unintended sharing
  - High overhead in adding/removing clients
- Event-based
  - Tedious and low level
  - Total control over scheduling
  - Very low overhead
  - Does not utilize multi-core
- Thread-based
  - Easy to share resources: Perhaps too easy
  - Medium overhead
  - Difficult to debug: event orderings not repeatable

---
layout: cover
class: text-center
background: bg.jpg
---

# Thank you for your listening!

Cat$^2$Fish❤