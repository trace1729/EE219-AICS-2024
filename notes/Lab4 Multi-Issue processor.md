
取指令，根据指令的类型分配解码单元。
  这里指令的译码是不是可以使用 chisel 去做。
      可能会引入额外的配置环境的成本，而且 chisel也是很久都没有使用了

static multi-issue and dynamic multi-issue

- static: hardware do not need to handle hazard, believe the compiler
- dynamic: hardware detect the hazard

New Knowledge will simply be vector instruction format.

VLEN: total bit width of a vec register (SEW * Elements Per Vec Reg)
LMUL: 
VLMAX: 

Mask Sett 

OPI-VV vector and vector
OPI-VX vector and scalar
OPI-VI  vector and immediate

unit-load/store

vm control bit in the section? what is mask used for?

simplified a lot, single-cycle, multi-issue processor.

TODO: using chisel to do more part.

把单周期的架子搭一下, 架子都已经搭好了，首要的任务是看每一个信号是在干什么。

每一个信号有三种子信号
- en: enable
- addr: address input
- dout: data output
## IF

当 reset 不为1时，开始取指，旧的pc作为指令地址，更新pc为pc+4
对于单发射来说，一旦拿到addr，取指可看作完成，inst_i 和 inst_o 是一致的。

![[Pasted image 20241222115233.png]]
