---
# You can also start simply with 'default'
theme: seriph
# random image from a curated Unsplash collection by Anthony
# like them? see https://unsplash.com/collections/94734566/slidev
background: bg.jpg
# some information about your slides (markdown enabled)
title: "Arch Lab"
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

# Arch Lab
## ICS Lab 04

Cat$^2$Fish❤


<!--
The last comment block of each slide will be treated as slide notes. It will be visible and editable in Presenter Mode along with the slide. [Read more in the docs](https://sli.dev/guide/syntax.html#notes)
-->

---
transition: fade-out
---

# PartA & PartB

Rather easy

- 由于这部分内容没什么好讲的，所以分享一些写的时候的小细节。
- 一个好用的 Y86-64 模拟器：https://boginw.github.io/js-y86-64/
- Clab 老是崩溃：WSL
- 改 PartB 的时候：Git。

---
transition: fade-out
---

# PartC

what is ac

- 可能是最困扰人的部分。
- 主线任务有两个：优化 ac 和 CPE
> In this lab, the length of the critical path is simplified as: 1 plus the maximum number of hardware devices (units) that line up in a path of the architecture
- 注意到 pipe_std 的 ac 为 4
- 根据评分标准，如果不将 ac 优化到 3，则 CPE 必须低于 7 才能满分
- 但是若将 ac 优化至 3，则 CPE 低于 9 就可以满分
- 后者相比前者更易做到。

---
transition: fade-out
---

# pipe_std 的 ac

cond?

![](/pipe_std.png)

---
transition: fade-out
---

# pipe_std 的 ac

cond?

- 在 E 阶段中，有一条 ALU->reg_cc->cond 的路径
- 正是这条路径使得 ac 高达 4
- 相应的解决方式也很简单，把他拆走就可以了。
- 简单说两种我试过的方法。

---
layout: image-right
image: sol1.jpg
---

# 加阶段

痛苦面具

- 保留 reg_cc 算出来的 CC，然后将其传到下一个我们单独拆出来的阶段中以计算 cnd
- 逻辑大致如右图所示，即从 E 阶段中分理出一个 C 阶段
- 由于 rust 的特性，调试较为困难，推荐安装 rust-analyzer 插件并在修改的时候做增量更新
- 要修改的地方不少，包括气泡/暂停逻辑、转发逻辑、最后的 printState 相关逻辑等，实现难度较高，很容易写出 bug

---
layout: image-right
image: sol1.jpg
---

# 加阶段（cont.）

痛苦面具

- 由于 pipeline 长度变长，气泡会不可避免地增多。
- 如果不对控制逻辑进一步修改，CPE 仍会高于 9
- 但该方法可以进行进一步扩展，以使 ac 进一步优化到 2（榜一大哥）
- 一些细节：关于 ConditionCode 的默认值

---
layout: image-right
image: sol2.jpg
---

# 直接修改 E

easy to implement

- 什么指令会设置 CC？
- 什么指令要用到 cnd？
- 注意到不存在一条在设置完 CC 后马上就要用到 cnd 的指令
- 所以完全没有必要在一个时钟周期内完成 alu->reg_cc->cond 的逻辑
- 完全可以先把 CC 存着，然后在下一个周期的时候用来算 cnd，如右图所示
- 这个做法的实现非常简单，只需要改几行代码即可。

---

# 优化 CPE

ncopy.ys

- 架构改完了，~~开始卡常吧~~
- 主要的优化思路都是差不多的

<div v-click>

- **循环展开**

</div>

<div v-click>

- 为什么循环展开可以降低 CPE？

</div>

<div v-click>

- 如何处理余数？二分法/三分法

</div>

<div v-click>

- 其他小细节：
  - 利用 iaddq 来减少指令条数
  - **尽力减少气泡个数**
    - load/use harzard
    - 分支预测错误

</div>


---
layout: two-cols
layoutClass: gap-16
---

# 我的初步实现

ncopy.ys

- 九路循环展开+三分法处理余数
- 一些细节：优先处理小余数
- 为什么？因为我们的分支预测逻辑是 always taken
- 优先减小余数小的情况的指令条数可以给减小 CPE 带来更高贡献
- 如右图所示
- 经过精细实现后 CPE 可达 7.96 左右

::right::

```asm
remainder:
  iaddq $7, %rdx
  jle R02
R38:
  isubq $3, %rdx
  jle R35
R68:
  isubq $2, %rdx
  mrmovq 40(%rdi), %rbx
  jl R6
  mrmovq 48(%rdi), %rcx
  je R7
  mrmovq 56(%rdi), %rbx
  jmp R8
R35:
  iaddq $1, %rdx
  mrmovq 16(%rdi), %rcx
  jl R3
  mrmovq 24(%rdi), %rbx
  je R4
  mrmovq 32(%rdi), %rcx
  jmp R5
R02:
  iaddq $1, %rdx
  mrmovq (%rdi), %rcx
  je R1
  mrmovq 8(%rdi), %rbx
  jg R2
  ret
```

---
layout: two-cols
layoutClass: gap-16
---

# 进一步优化

避免分支预测错误

我们可以发现，在循环的部分，我们有大量的 andq-jle 的跳转。每次分支预测错误都会造成两个气泡的额外开销。如果我们能完全避免呢？

事实上我们可以往这两个指令中间插入无关指令，使得 jle 在取指阶段的时候，andq 已经正确设置了 CC。这个时候就可以直接把 jle 的 ifun 传到 E 阶段计算 cond，进而直接判断是否进行跳转。

对于 pipe_std，我们只需要插入一条无关指令就可以了，事实上经过精细实现已经可以使得 CPE 小于 7，即在 ac=4 的情况下获得满分。

对于之前给出的 ac=3 的方案，我们需要插入两条无关指令（为什么）部分实现如右所示

::right::

```asm
Loop0:
  andq %r8, %r8
  rmmovq %r8, (%rsi)
  mrmovq 8(%rdi), %r9
  jle Loop1
  iaddq $1, %rax
```

```rs
u64 f_pc = [
  // Mispredicted branch. Fetch at incremented PC
  M.icode == JX && !M.cnd && !M.special_jmp : M.valA;
  ...
]
u64 f_pred_pc = [
  f_icode == JX && !(d_icode in { OPQ, IOPQ, JX })
   && !(e_icode in { OPQ, IOPQ, JX }) && !e_cnd : f_valP;
]
bool f_special_jmp = f_icode == JX && !(d_icode in { OPQ, IOPQ, JX }) && !(e_icode in { OPQ, IOPQ, JX });

u8 e_condfun = [ f_special_jmp: f_ifun; 1: e_ifun;];

@set_input(cond, {
  cc: cc,
  condfun: e_condfun,
});

bool e_cnd = cond.cnd;
```

---
layout: two-cols
layoutClass: gap-16
---

# 间接跳转

曲线救国

三分法仍不够快，我们考虑能不能实现一个跳转表。

由于本 lab 不支持自定义指令，所以我们只能用 pushq + ret 来模拟间接跳转。

具体实现的时候细节略多。具体见代码。

```asm
.pos 0x300 # 把 R8 的位置固定下来，方便我们找跳转地址
R8:
...
.pos 0x0700 # 跳转表
.align 2
jmptable: # R = 0 ... 8 对应的跳转地址
  .word 0x06fa
  .word 0x06d5
  .word 0x0681
  .word 0x064e
  .word 0x05a8
...
```

::right::

```asm
remainder:
  # 跳转表中地址以两个字节存储，这样可以减少指令条数
  addq %rdx, %rdx # 获取 2 倍的 (余数-9)
  mrmovq 0x0712(%rdx), %r8 # 前面的数字要加上 18 以抵消掉 -9
  iandq $0xffff, %r8 # 因为取地址的时候取到的是 quad，所以必须要and上0xffff
  pushq %r8 # push+ret 小连招
  ret
```

```rs
u64 f_pred_pc = [
  ...
  f_icode == RET && d_icode == PUSHQ : d_valA; // 直接预测跳转后的值
  ...
]

bool ret_harzard = (D.icode == RET && E.icode != PUSHQ) || (E.icode == RET && M.icode != PUSHQ) || (M.icode == RET && W.icode != PUSHQ);
// 在这种情况下我们是不需要RET冒险的，可以节省三个气泡
```

还有很多地方需要进行相应修改以配合这种特殊 RET，此处略过。


---

# 剩余卡常心得

嗯卡

- 我最终提交的 CPE 为 6.87
- 还有很多可以优化的空间，这里说一些刚才没提到的细节
- 由于 n=1 的时候其对总 CPE 的贡献可以说相当大，所以要尽力减少 n=1 时的指令条数（减少跳转，etc.）
- > #3453283
  >
  >  2022-04-20 12:57
  >
  > [洞主] 对了，歪个楼，archlab 的那个操作其实很简单。在第三个 lab 判定数组里面数字与 0 的关系时，在实现成二叉树的结构之后，只需要利用异或操作，两个两个地对数组里面的数字进行计数，就可以在这两个数字符号相反的时候节省一次额外判定的时间，从而很轻松地拿到满分。如果学过数字逻辑的同学应该能意识到这个就是半加器的原理。
- 利用上面所说的可以使得 CPE 进一步减少（吗）



---
layout: cover
class: text-center
background: bg2.jpg
---

# Thank you for your listening!

欢迎批评指正！
