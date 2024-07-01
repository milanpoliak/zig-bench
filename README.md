# Zig Bench

Simple benchmarking tool for Zig.

## How to use

### Install

1. Add Zig Bench to `build.zig.zon` dependencies

```shell
zig fetch --save https://github.com/milanpoliak/zig-bench/archive/refs/tags/v0.1.0.tar.gz
```

2. Add Zig Bench to `build.zig`

```zig
const zig_bench = b.dependency("zig-bench", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("zig-bench", zig_bench.module("zig-bench"));
```

### Run

```zig
// Import Zig Bench
const zig_bench = @import("zig-bench");
const Bench = zig_bench.Bench;
const Config = zig_bench.Config;
const table = zig_bench.table;

// Create void functions to benchmark
fn doSomething() void { ... }
fn doSomethingElse() void { ... }

// Create a writer (optional) and an allocator
const writer = std.io.getStdOut().writer();
const allocator = std.testing.allocator;
    
// Create a bench
var bench = Bench.init(testing.allocator, writer, Config {
    .runs = runs,
});
defer bench.deinit();

// Add the functions 
try bench.add("do something", doSomething);
try bench.add("do something else", doSomethingElse);

// (Optional) Add reference measurements (e.g. when comparing with functions in other languages, or competing with a challenge)
try bench.addReference("fast implementation somewhere else", 420);

// Run
try bench.run();

// Print results in a table (or use bench.measurements directly to report it in other formats)
try table.writeTable(&bench, std.io.getStdOut().writer(), allocator)
```

Example table output

```text
Name                    Min  Max  Mean  StdDev  P50  P75  P99
---------------------------------------------------------------
testing                 0    125  40    9.76    42   42   42
testing something else  0    125  40    8.57    42   42   42
```