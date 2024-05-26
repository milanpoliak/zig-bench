const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Timer = std.time.Timer;
const testing = std.testing;
const expect = testing.expect;
const Writer = std.fs.File.Writer;

const progress_indicator = "====================";
const progress_percent_step = 5;

const Measurement = struct {
    name: []const u8,
    times: ArrayList(u64),
    min: u64 = 0,
    max: u64 = 0,
    stdDev: f64 = 0,
    mean: u64 = 0,
    isReference: bool = false,

    fn deinit(self: *Measurement) void {
        self.times.deinit();
    }

    pub fn percentile(self: *Measurement, p: u8) u64 {
        if (self.times.items.len == 0) {
            return 0;
        }

        const index = @as(usize, @intFromFloat(@round((@as(f64, @floatFromInt(p)) / 100.0) * (@as(f64, @floatFromInt(self.times.items.len)) - 1.0))));

        return self.times.items[index];
    }
};

const Reference = struct {
    name: []const u8,
    time: u64,
};

pub const Config = struct {
    runs: u32,
};

const Definition = struct {
    name: []const u8,
    func: *const fn () void,
};

pub const Bench = struct {
    allocator: Allocator,
    writer: ?Writer,
    config: Config,
    definitions: ArrayList(Definition),
    measurements: ArrayList(Measurement),
    references: ArrayList(Reference),

    pub fn init(allocator: Allocator, writer: ?Writer, config: Config) Bench {
        return Bench {
            .allocator = allocator,
            .writer = writer,
            .config = config,
            .definitions = ArrayList(Definition).init(allocator),
            .measurements = ArrayList(Measurement).init(allocator),
            .references = ArrayList(Reference).init(allocator),
        };
    }

    pub fn deinit(self: *Bench) void {
        for (self.measurements.items) |measurement| {
            @constCast(&measurement).deinit();
        }

        self.definitions.deinit();
        self.measurements.deinit();
        self.references.deinit();
    }

    pub fn add(self: *Bench, name: []const u8, func: *const fn () void) !void {
        try self.definitions.append(Definition {
            .name = name,
            .func = func,
        });
    }

    pub fn addReference(self: *Bench, name: []const u8, time: u64) !void {
        try self.references.append(Reference {
            .name = name,
            .time = time,
        });
    }

    pub fn run(self: *Bench) !void {
        if (self.config.runs < 1) {
            return;
        }

        for (self.definitions.items) |definition| {
            self.runDefinition(&definition) catch |e| {
                try self.print("Unable to run \"{s}\": {}", .{definition.name, e});
            };
        }

        for (self.references.items) |reference| {
            try self.measurements.append(Measurement {
                .name = reference.name,
                .min = reference.time,
                .isReference = true,
                .times = ArrayList(u64).init(self.allocator),
            });
        }

        std.mem.sort(Measurement, self.measurements.items, {}, compareMeasurements);
    }

    fn runDefinition(self: *Bench, definition: *const Definition) !void {
        const runs = self.config.runs;

        var times = try ArrayList(u64).initCapacity(self.allocator, runs);
        var timer = try Timer.start();
        var sum: u64 = 0;
        
        try self.print("Running {s}: [{s: <20}] (0 / {})", .{definition.name, "", runs});

        var progress: u64 = 0;

        for (0..runs) |i| {
            const percent: u64 = @intFromFloat(@as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(runs)) * 100);

            if (percent > progress and percent % progress_percent_step == 0) {
                progress = percent;

                try self.print("\\33[2K\rRunning {s}: [{s: <20}] ({} / {})", .{definition.name, progress_indicator[0..(percent / progress_percent_step)], i, runs});
            }
            
            timer.reset();

            definition.func();

            const time = timer.read();

            sum += time;
            try times.append(time);
        }

        try self.print("\\33[2K\rRunning {s}: [{s: <20}] Done\n", .{definition.name, progress_indicator});

        std.mem.sort(u64, times.items, {}, std.sort.asc(u64));

        const mean = sum / times.items.len;

        try self.measurements.append(Measurement {
            .name = definition.name,
            .times = times,
            .min = times.items[0],
            .max = times.items[times.items.len - 1],
            .mean = mean,
            .stdDev = stdDeviation(times, @floatFromInt(mean)),
        });
    }

    fn print(self: *Bench, comptime format: []const u8, args: anytype) !void {
        if (self.writer) |w| {
            try w.print(format, args);
        }
    }
};

fn variance(list: std.ArrayList(u64), mean: f64) f64 {
    var sum: f64 = 0;

    for (list.items) |item| {
        const diff = @as(f64, @floatFromInt(item)) - mean;

        sum += diff * diff;
    }

    return sum / @as(f64, @floatFromInt(list.items.len));
}

fn stdDeviation(list: std.ArrayList(u64), mean: f64) f64 {
    const v = variance(list, mean);

    return std.math.sqrt(v);
}

fn compareMeasurements(_: void, lhs: Measurement, rhs: Measurement) bool {
    return lhs.min < rhs.min;
}

test "bench should measure all definitions" {
    const tests = struct {
        fn doSomething() void {}
        fn doSomethingElse() void {}
    };

    const runs = 1000;

    var bench = Bench.init(testing.allocator, null, Config {
        .runs = runs,
    });
    defer bench.deinit();
    
    try bench.add("testing", tests.doSomething);
    try bench.add("testing something else", tests.doSomethingElse);

    try bench.run();

    try expect(bench.measurements.items.len == 2);
    try expect(bench.measurements.items[0].times.items.len == runs);
    try expect(bench.measurements.items[1].times.items.len == runs);
}

test "bench should register references" {
    const tests = struct {
        fn doSomething() void {}
    };

    const runs = 10;

    var bench = Bench.init(testing.allocator, null, Config {
        .runs = runs,
    });
    defer bench.deinit();

    try bench.add("testing", tests.doSomething);

    // maybe not 100% deterministic, but in normal circumstances should always be last
    try bench.addReference("here is a reference", 10000000000);

    try bench.run();

    try expect(bench.measurements.items.len == 2);
    try expect(bench.measurements.items[0].times.items.len == runs);
    try expect(bench.measurements.items[1].times.items.len == 0); // references do not have counted runs
}
