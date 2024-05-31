# Zig Bench

Simple benchmarking tool for Zig.

## How to use

### Install

1. Add Zig Bench to `build.zig.zon` dependencies

```zig
...
.dependencies = .{
    .zig_bench = .{
        .url = "https://github.com/milanpoliak/zig-bench/archive/refs/tags/v0.0.2.tar.gz",
        .hash = "...", // TODO:
    },
},
...
```

2. Add Zig Bench to `build.zig`

```zig
const zig_bench = b.dependency("zig_bench", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("zig_bench", zig_bench.module("zig_bench"));
```

### Run

```zig
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
try writeTable(&bench, std.io.getStdOut().writer(), allocator)
```

Example table output

```text
Name                    Min  Max  Mean  StdDev  P50  P75  P99
---------------------------------------------------------------
testing                 0    125  40    9.76    42   42   42
testing something else  0    125  40    8.57    42   42   42
```