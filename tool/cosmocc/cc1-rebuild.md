# GCC 14.1.0 C front ends

The SDK includes two `cc1` programs for the x86-64 and AArch64 targets.
Both contain x86-64 and AArch64 host slices and embed the Cosmopolitan
runtime with the Windows memory-mapping fix shipped in `source/`.
The packaged `SHA256SUMS` records the two executable digests.

`rebuild-sireum-cc1.sh` in the Sireum Cosmopolitan source pins the
[Superconfigure build recipe](https://github.com/ahgamut/superconfigure/tree/dd04d27c780832318962efbc6d140743ebff617b),
[ported GCC source](https://github.com/ahgamut/gcc/tree/58ccca83f6ce7f33ee3bf1333a1e152a0a2486b7),
and [embedded Cosmopolitan runtime source](https://github.com/jart/cosmopolitan/tree/1312f602450da58f31a8ca81322257ec61f584b9).
It uses the upstream `x86_64-gcc` and `aarch64-gcc` make targets and
the stock Cosmocc 4.0.2 bootstrap.
