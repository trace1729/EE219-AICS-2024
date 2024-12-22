#import "template.typ": *

#show: project.with(
  title: "Laboratory 5",
  authors: (
    (
      name: "龚开宸",
      email: "gongkch2024@shanghaitech.edu.cn"
    ),
  ),
)

What happens after I type `make demo`: 


lab4/makefile: run target which depends on

- init
 - create nessary dirs
- matrix 
 - Use `MatrixGen.py` to generate data, and put data and result in specified location
- compile
 - use `compile.py` to compile asm to machine execitable code (bin) specified by IMG and ISSUE
- build: 
  - ./tools/verilator/build.sh -b -v -GISSUE_NUM
  - `b`: build=true: build_proj()
  - `v`: set verilator flags
- sim: 
  - ./tools/verilator/build.sh -s -a -GISSUE_NUM
  - `s` simulate=true
  - `a` set PARAMETERS
   - `EXECUABLE PARAMETERS`
   - depend on `main.cpp` to dump data.
- test:
 - test_inst
  - use `TestInst1.py`
 - test_mac