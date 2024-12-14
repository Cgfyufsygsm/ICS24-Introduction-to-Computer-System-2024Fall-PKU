---
# You can also start simply with 'default'
theme: seriph
# random image from a curated Unsplash collection by Anthony
# like them? see https://unsplash.com/collections/94734566/slidev
background: bg.jpg
# some information about your slides (markdown enabled)
title: "Review: Procedures"
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
  sans: "华文中宋"
  local: "华文中宋"
---

# Review: Procedures
## (CS: APP, Ch. 3.7)

Taoyu Yang, EECS, PKU


<!--
The last comment block of each slide will be treated as slide notes. It will be visible and editable in Presenter Mode along with the slide. [Read more in the docs](https://sli.dev/guide/syntax.html#notes)
-->

---
transition: fade-out
---

# Contents

Procedures

- **Lecture Review**
  - Runtime Stack
  - Calling Conventins
    - Passing Control
    - Passing Data
    - Managing Local Data
  - Recursion
- **Exercises & Supplementary Contents**

<!--
You can have `style` tag in markdown to override the style for the current page.
Learn more: https://sli.dev/features/slide-scope-style
-->


<!--
Here is another comment.
-->

---
layout: image-right
image: stack.png
---

# Runtime Stack

x86-64

## Region of memory managed with stack discipline

<br>

- stack pointer %rsp
- stack frame

<!-- 以栈的形式管理一段内存。以 P 调用 Q 为例，Q 运行的时候 P 以及之前的东西都是被挂起的，Q 需要的话就会分配一段空间，Q 运行结束的时候就会被释放，与我们所知道的函数的调用模式相符。栈是用高地址像低地址增长的，%rsp 寄存器存储着栈顶的地址，利用 pushq 和popq 可以在栈上存储内容或是取出内容。一个过程在栈上分配的空间称为栈帧。比如保存寄存器的值，分配局部变量，超过6个的参数，以及返回地址。 -->

---
# layout: two-cols
# layoutClass: gap-16
---

# Push and Pop

小细节

```asm {1|2-4|5-6|7-9|all} twoslash
pushq %rbp

subq $8, %rsp
movq %rbp, (%rsp)

popq %rax

movq (%rsp), %rax
addq $8, %rsp 
```

<br>


<div v-click>


### popq doesn't change the memory! Only the value of `%rsp` is changed.

</div>

---

# Passing Control

call and return

- Uses runtime stack to support all these operations
- **Procedure call**: `call label`
  - *push return address on stack*
  - jump
- Return address
  - next instruction after call
- **Procedure return**: `ret`
  - *pop address from stack*
  - jump

---
layout: two-cols
layoutClass: gap-16
---

# Passing Control: Example

```asm {all|16|6-7|8|9|1-2|3|4|4,10|10|10,17|17|all}
0000000000400540 <last>:
  400540:  48 89 f8                  mov    %rdi,%rax
  400543:  48 0f af c6               imul   %rsi,%rax
  400547:  c3                        retq

0000000000400548 <first>:
  400548:  48 8d 77 01               lea    0x1(%rdi),%rsi
  40054c:  48 83 ef 01               sub    $0x1,%rdi
  400550:  e8 eb ff ff ff            call   400540 <last>
  400555:  f3 c3                     repz retq

.
.
.

  400560:  e8 e3 ff ff ff            callq 400548 <first>
  400565:  48 89 c2                  mov   %rax,%rdx
```

::right::

<br><br>

Consider how %rsp and *%rsp changes as the program runs.

```c
long last(long a, long b) {
  return a * b;
}

long first(long x) {
  return last(x - 1, x + 1);
}

int main() {
  ...
  first(10)
}
```

---
layout: two-cols
layoutClass: gap-16
---

# Passing Data

arguments

### First 6 arguments

(64 bits)
- `%rdi`
- `%rsi`
- `%rdx`
- `%rcx`
- `%r8`
- `%r9`

### Return value

- `%rax`

::right::

<br><br>

<div v-click>

### Stack

- ...
- Arg n
- ...
- Arg 8
- Arg 7

</div>

<br><br>

<div v-click>

### Only allocate stack when needed

</div>

---
layout: two-cols
layoutClass: gap-16
---

# Example

```asm

# Arguments:
#   a1  in %rdi           64
#   a1p in %rsi           64
#   a2  in %edx           32
#   a2p in %rcx           64
#   a3  in %r8w           16
#   a3p in %r9            64
#   a4  at %rsp+8         8
#   a4p at %rsp+16        64

proc:
  movq    16(%rsp), %rax
  addq    %rdi, (%rsi)
  addl    %edx, (%rcx)
  addw    %r8w, (%r9)
  movl    8(%rsp), %edx
  addb    %dl, (%rax)
  ret
```

::right::

<br><br>

```c
void proc(long a1, long *a1p,
          int a2, int *a2p,
          short a3, short *a3p,
          char a4, char *a4p)
{
  *a1p += a1;
  *a2p += a2;
  *a3p += a3;
  *a4p += a4;
}
```

### What is in the stack?

<!-- 从低地址到高地址：返回地址，a4，空地址用于对齐，a4p -->

---

# Local Data Management: Stack

local variables?

Sometimes variables must be stored in memory.

- Registers are not enough
- Trying to get the address of a local variable using `&`
- Array or Structures

Procedures allocate space on stack by decresing stack pointer. The result is a part of stack frame.

---
layout: two-cols
layoutClass: gap-16
---

# Example

swap and add

```c
long swap_add(long *xp, long *yp) {
  long x = *xp;
  long y = *yp;
  *xp = y;
  *yp = x;
  return x + y;
}

long caller() {
  long arg1 = 534;
  long arg2 = 1057;
  long sum = swap_add(&arg1, &arg2);
  long diff = arg1 - arg2;
  return sum * diff;
}
```

::right::

<br><br>

```asm {all|2,11|all}
caller:
  subq   $16, %rsp
  movq   $534, (%rsp)
  movq   $1057, 8(%rsp)
  leaq   8(%rsp), %rsi
  movq   %rsp, %rdi
  call   swap_add
  movq   (%rsp), %rdx
  subq   8(%rsp), %rdx
  imulq  %rdx, %rax
  addq   $16, %rsp
```

<br>

<div v-click>

> *Maybe a useful advice in DSA:*
>
> Always initialize a local variable when creating it!

</div>

---
layout: two-cols
layoutClass: gap-16
---

# Example in Bomblab

Phase_2

In phase 2, the six numbers read via `read_six_numbers` is stored in the stack as follows:

`(%rsp), $0x4(%rsp), $0x8(%rsp), $0xc(%rsp), $0x10(%rsp), $0x14(%rsp)`

`(%rsp, %rcx, 4)` is actually getting the `%rcx`-th element.

::right::

```asm
00000000000027dc <phase_2>:
    27dc:	f3 0f 1e fa          	endbr64
    27e0:	53                   	push   %rbx
    27e1:	48 83 ec 20          	sub    $0x20,%rsp
    ...
    27f8:	e8 cf 08 00 00       	call   30cc <read_six_numbers>
    27fd:	83 3c 24 00          	cmpl   $0x0,(%rsp)
    2801:	75 07                	jne    280a <phase_2+0x2e>
    2803:	83 7c 24 04 01       	cmpl   $0x1,0x4(%rsp)
    2808:	74 05                	je     280f <phase_2+0x33>
    280a:	e8 37 08 00 00       	call   3046 <explode_bomb>
    280f:	bb 02 00 00 00       	mov    $0x2,%ebx
    2814:	eb 03                	jmp    2819 <phase_2+0x3d>
    2816:	83 c3 01             	add    $0x1,%ebx
    2819:	83 fb 05             	cmp    $0x5,%ebx
    281c:	7f 20                	jg     283e <phase_2+0x62>
    281e:	48 63 d3             	movslq %ebx,%rdx
    2821:	8d 4b fe             	lea    -0x2(%rbx),%ecx
    2824:	48 63 c9             	movslq %ecx,%rcx
    2827:	8d 43 ff             	lea    -0x1(%rbx),%eax
    282a:	48 98                	cltq
    282c:	8b 04 84             	mov    (%rsp,%rax,4),%eax
    282f:	03 04 8c             	add    (%rsp,%rcx,4),%eax
    2832:	39 04 94             	cmp    %eax,(%rsp,%rdx,4)
```

---

# Local Data Management: Registers

a bit complicated

Registers are shared among all procedures.

So we have to make sure when a procedure (**caller**) calls another procedure (**callee**), callee will not overwrite the register value caller might use later.

x86-64 adapts to these conventions:

- **Caller Saved**
  - Caller saves temporary values in its frame before the call
- **Callee Saved**
  - Callee saves temporary values in its frame before using
  - Callee restores them before returning to caller

---
layout: two-cols
layoutClass: gap-16
---

# Register Usage #1

caller-Saved

- `%rax`
  - Return value
  - Caller-saved
  - can be modified by the procedure
- `%rdi,...,%r9`
  - Arguments
  - Caller-saved
  - can be modified by the procedure
- `%r10, %r11`
  - Caller-saved
  - can be modified by the procedure

::right::
<br>

![](/register1.png)

---
layout: two-cols
layoutClass: gap-16
---

# Register Usage #2

callee-saved

- `%rbx, %r12, %r13, %r14`
  - Callee-saved
  - Callee must save and restore
- `%rbp`
  - Callee-saved
  - Callee must save & restore
  - **May be used as frame pointer**
  - Can mix & match
- `%rsp`
  - Special form of callee-saved
  - Restored to original value upon exit from procedure

::right::

<br><br>

![](/register2.png)

---

# Recursion

call itself!

Calling a function itself is no different with calling another function.

Every function call has its own space for its private status data thanks to stack mechanisms.

```asm
rfact:
  pushq   %rbx            # save rbx
  movq    %rdi, %rbx
  movl    $1, %eax
  cmpq    $1, %rdi
  jle     .L35
  leaq    -1(%rdi), %rdi
  call    rfact
  imulq   %rbx, %rax
.L35:
  popq    %rbx
  ret
```

---
class: text-center
layout: center
# background: 0xffffff
---

# Exercises & Supplementary Contents

---

# Exercises

From 2023 Midterm

7、考虑在 x86-64 + Linux 情景，在使用 call 指令进行过程/函数调用时，计算机会做如下哪一条描述的事情：

  A. 将此 call 指令的下一条指令的地址放入栈中

  B. 将此 call 指令的下一条指令的地址放入 `%rsp` 寄存器中
  
  C. 将此 call 指令的地址放入栈中

  D. 将此 call 指令的地址放入 `%rsp` 寄存器中

<div v-click>

Answer: A

</div>
---

# Exercises

From 2020 Midterm

4、下列关于 x86-64 过程调用的叙述中，哪一个是不正确的？

A. 每次递归调用都会生成一个新的栈帧，空间开销大

B. 当传递给被调用函数的参数少于 6 个时，可以通过通用寄存器传递

C. 被调用函数要为局部变量分配空间，返回时无需释放这些空间

D. 过程调用返回时，向程序计数器中推送的地址是调用函数中调用指令的下一条
指令的地址

<div v-click>

Answer: C

</div>

---

# Exercises

Unknown source

5、已知函数 `func` 的参数超过 6 个，当 x86-64 机器执行完指令 `call func` 之后，`%rsp` 的值为 $S$。那么 `func` 的第 $k~(k>6)$ 个参数的存储地址是？

A. $S + 8\times (k - 6)$

B. $S + 8\times (k - 7)$

C. $S - 8\times (k - 6)$

D. $S - 8\times (k - 7)$


<div v-click>

Answer: A

</div>

---
layout: two-cols
layoutClass: gap-16
transition: fade
---

# Memory Layout

heap and stack?

- **Code Segment**: Contains the compiled code of the program.
- **Data Segment**: For global and static variables, which includes:
  - Initialized Data Segment: Contains initialized global and static variables.
  - Uninitialized Data Segment (BSS): Contains uninitialized global and static variables.
- **Heap**: For dynamic memory allocation (manual management).
- **Stack**

::right::

![](/layout.png)


---
layout: two-cols
layoutClass: gap-16
transition: fade
---

# Memory Layout

heap and stack?

- **Code Segment**: Contains the compiled code of the program.
- **Data Segment**: For global and static variables, which includes:
  - Initialized Data Segment: Contains initialized global and static variables.
  - Uninitialized Data Segment (BSS): Contains uninitialized global and static variables.
- **Heap**: For dynamic memory allocation (manual management).
- **Stack**

::right::

<br><br>

```c {all|3,4,10-13,17-19|7-10,12|14,15|all}
#include "stdio.h"

int a = 2; // Initialized Data Segment
char *p1; // BSS, note that it will be initialized to 0

int main() {
  int b; // stack  
  char s[] = "abc"; // stack
  char *p2; // stack
  char *p3 = "123456";
  // The string constant is in Initialized Data Segment
  // p3 is on stack
  static int c = 0;// Initialized Data Segment
  p1 = (char*)malloc(10);    
  p2 = (char*)malloc(20);    
  // 10 and 20 bits in heap area
  strcpy(p1, "123456");
  // 123456\0 is in Initialized Data Segment
  // compiler might do optimization
}
```

---
layout: two-cols
layoutClass: gap-16
transition: fade
---

# Memory Layout

heap and stack?

- **Code Segment**: Contains the compiled code of the program.
- **Data Segment**: For global and static variables, which includes:
  - Initialized Data Segment: Contains initialized global and static variables.
  - Uninitialized Data Segment (BSS): Contains uninitialized global and static variables.
- **Heap**: For dynamic memory allocation (manual management).
- **Stack**

::right::

<br><br>

Another example in bomblab:

```asm
00000000000027b8 <phase_1>:
    ...
    27c0:	48 8d 35 39 2a 00 00 	lea    0x2a39(%rip),%rsi        # 5200 <_IO_stdin_used+0x200>

0000000000002a8c <phase_6>:
    2b22:	48 8d 15 e7 65 00 00 	lea    0x65e7(%rip),%rdx  # 9110 <node1>
```

In these 2 examples, the string in phase 1 and the linked-list in phase 6 is global data and stored in data segment.

---

# Stack Size

might be a useful trick for DSA

To enable the concurrent execution of multiple threads, compilers typically allocate a limited amount of stack memory per thread, often ranging from 1 to 8 MB.

So **excessive recursion or too many local variables** may lead to **stack overflow**, causing the program to crash.

<div v-click>

This rarely occurs on OJ, since the stack size is usually set the same as the memory limit. But it is still annoying when you try to debug your program which performs DFS on a tree with a depth of $10^5$ (especially when it is a chain) on your machine, as 8MB is definetely insufficient.

</div>

<div v-click>

For Windows, adding the option `-Wl,--stack=SIZE` when compiling might help, where SIZE is specified in bytes.

In Linux you can also use command `ulimit -s`.

</div>

---
layout: two-cols
layoutClass: gap-16
transition: fade
---

# Indirect jump

function pointer?

Up till now we have only seen direct jump.

So when does indirect jump happen?

An example is function pointer:

```c
#include <stdio.h>

void target_function() {
    printf("Target function called!\n");
}

int main() {
    void (*func_ptr)() = target_function; // 函数指针
    func_ptr(); // 间接调用目标函数
    return 0;
}
```

::right::

```asm {24|all}
.section .data
.LC0:
    .string "Target function called!"

.text
.global main

target_function:
    pushq   %rbp
    movq    %rsp, %rbp
    movq    $.LC0, %rdi
    call    puts
    nop
    popq    %rbp
    ret

main:
    pushq   %rbp
    movq    %rsp, %rbp
    subq    $16, %rsp
    movq    $target_function, -8(%rbp)
    movq    -8(%rbp), %rdx
    movl    $0, %eax
    call    *%rdx
    movl    $0, %eax
    leave
    ret
```

---
layout: two-cols
layoutClass: gap-16
transition: fade
---

# Polymorphism

virtual functions?

```cpp
#include <iostream>

using namespace std;

struct Base {
    virtual void greet() {
        cout << "Base" << endl;
    }
};

struct Derived : public Base {
    virtual void greet() override {
        cout << "Derived" << endl;
    }
};

int main() {
    Derived d;
    Base& b = d;
    b.greet();
    return 0;
}
```

::right::

```asm
main:
  pushq   %rbp              ; 保存旧的基指针
  movq    %rsp, %rbp        ; 设置新的基指针
  subq    $16, %rsp         ; 为局部变量分配空间
  movl    $vtable for Derived+16, %eax 
     ; 将 Derived 类的 vtable 地址加载到 %eax
  movq    %rax, -16(%rbp)   ; 将 vtable 地址存储在栈上
  leaq    -16(%rbp), %rax   ; 获取 vtable 地址的指针
  movq    %rax, -8(%rbp)    ; 存储 vtable 地址到另一个局部变量
  movq    -8(%rbp), %rax    ; 取出 vtable 地址
  movq    (%rax), %rax      ; 获取 vtable 中的第一个指针，即基类的虚函数指针
  movq    (%rax), %rdx      ; 获取虚函数地址
  movq    -8(%rbp), %rax    ; 重新加载 vtable 地址
  movq    %rax, %rdi        ; 将 this 指针（Derived 对象的地址）存入 %rdi
  call    *%rdx             ; 调用 Derived::greet()
  movl    $0, %eax          ; 设置返回值为 0
  leave                     ; 清理栈帧
  ret                        ; 返回
vtable for Derived:
  .quad   0
  .quad   typeinfo for Derived
  .quad   Derived::greet()
```

---
layout: two-cols
layoutClass: gap-16
transition: fade
---

# Frame Pointer

`%rbp`

To manage variable-length frame stack, x86-64 uses `%rbp` as the **frame pointer** or **b**ase **p**ointer. 

It's a callee-saved register.

It points to the base of the current stack frame.

See page 203 for detail.

```c
long vframe(long n, long idx, long *q) {
    long i;
    long *p[n];
    p[0] = &i;
    for (i = 1; i < n; ++i) p[i] = q;
    return *p[idx];
}
```

::right::

```asm
vframe:
	pushq %rbp 					# Save old %rbp
	movq %rsp, %rbp 			# Set frame pointer
	subq $16, %rsp 				# Allocate space for i (%rsp = s1，结合下图看)
	leaq 22(,%rdi,8), %rax
	andq $-16, %rax
	subq %rax, %rsp 			# Allocate space for array p(%rsp = s2，结合下图看)
	leaq 7(%rsp), %rax
	shrq $3, %rax
	leaq 0(,%rax,8), %r8 		# Set %r8 to &p[0]
	movq %r8, %rcx 				# Set %rcx to &p[0] (%rcx = p)
...
# Code for initialization loop
.L3: loop:
	movq %rdx, (%rcx,%rax,8) 	Set p[i] to q
	addq $1, %rax 				# Increment i
	movq %rax, -8(%rbp) 		# Store on stack
.L2:
	movq -8(%rbp), %rax 		# Retrieve i from stack
	cmpq %rdi, %rax 			# Compare i:n
	jl .L3 						# If <, goto loop
...
# Code for function exit
	leave 						# Restore %rbp and %rsp
	ret 						# Return

```

---
layout: center
class: text-center
---

# Thank you for your listening!


<PoweredBySlidev mt-10 />
