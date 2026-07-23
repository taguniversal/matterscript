// generate.zig
// Parser and AST for the MatterScript table generator.
//
// The generate block replaces explicit key:value pairs in a constant table
// with a compile-time expression that is evaluated for all input combinations.
//
// Syntax:
//   $a$b() : generate {
//     clamp(($a + $b) / 2, 0, 7)
//     inputs: $a 0..7, $b 0..7
//     output: 0..7
//     const resistance = 2
//   }
//
// Rules:
//   - Expression comes first, before inputs:
//   - inputs: is mandatory, lists each destination variable with its range
//   - output: is mandatory, defines the output clamp range
//   - const declarations are optional, appear after output:
//   - Variables are referenced with $ prefix
//   - Named constants are referenced without $ prefix
//   - No floating point anywhere — all arithmetic is integer

const std = @import("std");

// -----------------------------------------------------------------------
// Expression AST
// -----------------------------------------------------------------------

pub const BinaryOp = enum { add, sub, mul, div };

pub const ExprKind = enum {
    integer,    // literal integer value
    variable,   // $name — a destination place value
    constant,   // name — a named constant (no $ prefix)
    binary,     // expr op expr
    call,       // func(args...)
};

pub const Expr = struct {
    kind: ExprKind,
    // integer literal
    int_val: i64 = 0,
    // variable or constant name (without $ prefix)
    name: []const u8 = "",
    // binary operation
    op: BinaryOp = .add,
    left: ?*Expr = null,
    right: ?*Expr = null,
    // function call
    func: []const u8 = "",
    args: []const *Expr = &.{},
};

pub const FuncKind = enum { clamp, avg };

// -----------------------------------------------------------------------
// Generate block AST
// -----------------------------------------------------------------------

pub const InputDecl = struct {
    /// Variable name without $ prefix
    name: []const u8,
    min: i64,
    max: i64,
};

pub const ConstDecl = struct {
    name: []const u8,
    value: i64,
};

pub const GenerateBlock = struct {
    /// The expression to evaluate for each input combination
    expr: *Expr,
    /// Input variable declarations with ranges
    inputs: []const InputDecl,
    /// Output range for clamping the result
    output_min: i64,
    output_max: i64,
    /// Named integer constants referenced in the expression
    constants: []const ConstDecl,
};

// -----------------------------------------------------------------------
// Parser
// -----------------------------------------------------------------------

pub const ParseError = error{
    UnexpectedEnd,
    UnexpectedToken,
    ExpectedKeyword,
    ExpectedInteger,
    ExpectedRange,
    ExpectedDollar,
    ExpectedName,
    UnknownFunction,
    OutOfMemory,
};

const Parser = struct {
    src: []const u8,
    pos: usize,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator, src: []const u8) Parser {
        return .{ .src = src, .pos = 0, .allocator = allocator };
    }

    fn peek(p: *Parser) ?u8 {
        if (p.pos >= p.src.len) return null;
        return p.src[p.pos];
    }

    fn advance(p: *Parser) ?u8 {
        if (p.pos >= p.src.len) return null;
        const c = p.src[p.pos];
        p.pos += 1;
        return c;
    }

    fn skipWhitespace(p: *Parser) void {
        while (p.pos < p.src.len) {
            const c = p.src[p.pos];
            if (c == ' ' or c == '\t' or c == '\n' or c == '\r') {
                p.pos += 1;
            } else if (c == '/' and p.pos + 1 < p.src.len and
                       p.src[p.pos + 1] == '/') {
                while (p.pos < p.src.len and p.src[p.pos] != '\n')
                    p.pos += 1;
            } else break;
        }
    }

    fn expect(p: *Parser, ch: u8) !void {
        p.skipWhitespace();
        if (p.peek() != ch) return ParseError.UnexpectedToken;
        _ = p.advance();
    }

    fn tryConsume(p: *Parser, ch: u8) bool {
        p.skipWhitespace();
        if (p.peek() == ch) { _ = p.advance(); return true; }
        return false;
    }

    fn readName(p: *Parser) ![]const u8 {
        p.skipWhitespace();
        const start = p.pos;
        while (p.pos < p.src.len) {
            const c = p.src[p.pos];
            if (std.ascii.isAlphanumeric(c) or c == '_') {
                p.pos += 1;
            } else break;
        }
        if (p.pos == start) return ParseError.ExpectedName;
        return p.src[start..p.pos];
    }

    fn readInteger(p: *Parser) !i64 {
        p.skipWhitespace();
        const negative = p.tryConsume('-');
        const start = p.pos;
        while (p.pos < p.src.len and std.ascii.isDigit(p.src[p.pos]))
            p.pos += 1;
        if (p.pos == start) return ParseError.ExpectedInteger;
        const val = try std.fmt.parseInt(i64, p.src[start..p.pos], 10);
        return if (negative) -val else val;
    }

    fn readRange(p: *Parser) !struct { min: i64, max: i64 } {
        const min = try p.readInteger();
        p.skipWhitespace();
        // expect ..
        if (p.pos + 1 >= p.src.len or
            p.src[p.pos] != '.' or p.src[p.pos + 1] != '.')
            return ParseError.ExpectedRange;
        p.pos += 2;
        const max = try p.readInteger();
        return .{ .min = min, .max = max };
    }

    fn peekKeyword(p: *Parser, kw: []const u8) bool {
        const saved = p.pos;
        p.skipWhitespace();
        const start = p.pos;
        while (p.pos < p.src.len) {
            const c = p.src[p.pos];
            if (std.ascii.isAlphanumeric(c) or c == '_') {
                p.pos += 1;
            } else break;
        }
        const word = p.src[start..p.pos];
        const matches = std.mem.eql(u8, word, kw);
        p.pos = saved;
        return matches;
    }

    fn consumeKeyword(p: *Parser, kw: []const u8) !void {
        p.skipWhitespace();
        const name = try p.readName();
        if (!std.mem.eql(u8, name, kw)) return ParseError.ExpectedKeyword;
        // consume optional colon after keyword (for inputs: output:)
        _ = p.tryConsume(':');
    }

    // -----------------------------------------------------------------------
    // Expression parser — recursive descent with precedence
    // -----------------------------------------------------------------------

    fn parseExpr(p: *Parser) !*Expr {
        return p.parseAddSub();
    }

    fn parseAddSub(p: *Parser) !*Expr {
        var left = try p.parseMulDiv();
        while (true) {
            p.skipWhitespace();
            const op: BinaryOp = if (p.peek() == '+') .add
                                  else if (p.peek() == '-') .sub
                                  else break;
            _ = p.advance();
            const right = try p.parseMulDiv();
            const node = try p.allocator.create(Expr);
            node.* = .{
                .kind = .binary,
                .op = op,
                .left = left,
                .right = right,
            };
            left = node;
        }
        return left;
    }

    fn parseMulDiv(p: *Parser) !*Expr {
        var left = try p.parseUnary();
        while (true) {
            p.skipWhitespace();
            const op: BinaryOp = if (p.peek() == '*') .mul
                                  else if (p.peek() == '/') .div
                                  else break;
            _ = p.advance();
            const right = try p.parseUnary();
            const node = try p.allocator.create(Expr);
            node.* = .{
                .kind = .binary,
                .op = op,
                .left = left,
                .right = right,
            };
            left = node;
        }
        return left;
    }

    fn parseUnary(p: *Parser) !*Expr {
        p.skipWhitespace();
        // parenthesized expression
        if (p.peek() == '(') {
            _ = p.advance();
            const inner = try p.parseExpr();
            try p.expect(')');
            return inner;
        }
        // variable: $name
        if (p.peek() == '$') {
            _ = p.advance();
            const name = try p.readName();
            const node = try p.allocator.create(Expr);
            node.* = .{ .kind = .variable, .name = name };
            return node;
        }
        // integer literal
        if (p.pos < p.src.len and
            (std.ascii.isDigit(p.src[p.pos]) or p.src[p.pos] == '-')) {
            const val = try p.readInteger();
            const node = try p.allocator.create(Expr);
            node.* = .{ .kind = .integer, .int_val = val };
            return node;
        }
        // name — either a function call or a constant reference
        const name = try p.readName();
        p.skipWhitespace();
        if (p.peek() == '(') {
            // function call
            _ = p.advance(); // (
            var args: std.ArrayListUnmanaged(*Expr) = .empty;
            p.skipWhitespace();
            while (p.peek() != ')' and p.peek() != null) {
                const arg = try p.parseExpr();
                try args.append(p.allocator, arg);
                p.skipWhitespace();
                _ = p.tryConsume(',');
                p.skipWhitespace();
            }
            try p.expect(')');
            const node = try p.allocator.create(Expr);
            node.* = .{
                .kind = .call,
                .func = name,
                .args = try args.toOwnedSlice(p.allocator),
            };
            return node;
        }
        // named constant (no $ prefix, no parens)
        const node = try p.allocator.create(Expr);
        node.* = .{ .kind = .constant, .name = name };
        return node;
    }

    // -----------------------------------------------------------------------
    // Generate block parser
    // -----------------------------------------------------------------------

    fn parseGenerateBlock(p: *Parser) !GenerateBlock {
        // consume 'generate'
        try p.consumeKeyword("generate");
        try p.expect('{');

        // read the expression — everything up to the 'inputs' keyword
        const expr_src_start = p.pos;
        while (p.pos < p.src.len) {
            if (p.peekKeyword("inputs")) break;
            p.pos += 1;
        }
        const expr_src = std.mem.trim(u8, p.src[expr_src_start..p.pos], " \t\n\r");

        // re-parse the expression from the extracted source
        var expr_parser = Parser.init(p.allocator, expr_src);
        const expr = try expr_parser.parseExpr();

        // inputs: $name min..max, ...
        try p.consumeKeyword("inputs");
        var inputs: std.ArrayListUnmanaged(InputDecl) = .empty;
        p.skipWhitespace();
        while (p.pos < p.src.len) {
            p.skipWhitespace();
            if (!p.peekKeyword("output") and p.peek() == '$') {
                _ = p.advance(); // $
                const name = try p.readName();
                p.skipWhitespace();
                const range = try p.readRange();
                try inputs.append(p.allocator, .{
                    .name = name,
                    .min = range.min,
                    .max = range.max,
                });
                p.skipWhitespace();
                _ = p.tryConsume(',');
            } else break;
        }

        // output: min..max
        try p.consumeKeyword("output");
        const out_range = try p.readRange();

        // const name = value (zero or more)
        var constants: std.ArrayListUnmanaged(ConstDecl) = .empty;
        while (true) {
            p.skipWhitespace();
            if (p.peek() == '}') break;
            if (p.peekKeyword("const")) {
                try p.consumeKeyword("const");
                const name = try p.readName();
                try p.expect('=');
                const val = try p.readInteger();
                try constants.append(p.allocator, .{
                    .name = name,
                    .value = val,
                });
            } else break;
        }

        try p.expect('}');

        return GenerateBlock{
            .expr = expr,
            .inputs = try inputs.toOwnedSlice(p.allocator),
            .output_min = out_range.min,
            .output_max = out_range.max,
            .constants = try constants.toOwnedSlice(p.allocator),
        };
    }
};

// -----------------------------------------------------------------------
// Public API
// -----------------------------------------------------------------------

/// Parse a generate block from source text starting at 'generate {'.
/// Returns the parsed GenerateBlock AST.
pub fn parse(allocator: std.mem.Allocator, source: []const u8) !GenerateBlock {
    var p = Parser.init(allocator, source);
    return p.parseGenerateBlock();
}

// -----------------------------------------------------------------------
// Expression evaluator
// -----------------------------------------------------------------------

/// Evaluate an expression given a map of variable name -> value
/// and a map of constant name -> value.
/// Returns the integer result.
pub fn eval(
    expr: *const Expr,
    variables: std.StringHashMap(i64),
    constants: std.StringHashMap(i64),
) !i64 {
    return switch (expr.kind) {
        .integer => expr.int_val,

        .variable => variables.get(expr.name) orelse {
            std.debug.print("undefined variable: ${s}\n", .{expr.name});
            return ParseError.UnexpectedToken;
        },

        .constant => constants.get(expr.name) orelse {
            std.debug.print("undefined constant: {s}\n", .{expr.name});
            return ParseError.UnexpectedToken;
        },

        .binary => {
            const l = try eval(expr.left.?, variables, constants);
            const r = try eval(expr.right.?, variables, constants);
            return switch (expr.op) {
                .add => l + r,
                .sub => l - r,
                .mul => l * r,
                .div => if (r == 0) 0 else @divTrunc(l, r),
            };
        },

        .call => {
            if (std.mem.eql(u8, expr.func, "clamp")) {
                if (expr.args.len != 3) return ParseError.UnexpectedToken;
                const val = try eval(expr.args[0], variables, constants);
                const lo  = try eval(expr.args[1], variables, constants);
                const hi  = try eval(expr.args[2], variables, constants);
                return @max(lo, @min(hi, val));
            }
            if (std.mem.eql(u8, expr.func, "avg")) {
                if (expr.args.len == 0) return 0;
                var sum: i64 = 0;
                for (expr.args) |arg| {
                    sum += try eval(arg, variables, constants);
                }
                return @divTrunc(sum, @as(i64, @intCast(expr.args.len)));
            }
            std.debug.print("unknown function: {s}\n", .{expr.func});
            return ParseError.UnknownFunction;
        },
    };
}

// -----------------------------------------------------------------------
// Table enumeration
// -----------------------------------------------------------------------

pub const TableEntry = struct {
    key: []const u8,   // binary string key
    value: i64,
};

/// Enumerate all input combinations and evaluate the expression for each.
/// Returns a slice of TableEntry with binary string keys.
/// The key format matches the IL parser's expectation:
/// one character per input variable, in declaration order.
pub fn enumerate(
    allocator: std.mem.Allocator,
    block: GenerateBlock,
) ![]const TableEntry {
    // build constant map
    var const_map = std.StringHashMap(i64).init(allocator);
    defer const_map.deinit();
    for (block.constants) |c| {
        try const_map.put(c.name, c.value);
    }

    var entries: std.ArrayListUnmanaged(TableEntry) = .empty;

    // recursive enumeration over inputs
    var var_map = std.StringHashMap(i64).init(allocator);
    defer var_map.deinit();

    try enumerateRecursive(
        allocator,
        block,
        block.inputs,
        &var_map,
        const_map,
        &entries,
    );

    return entries.toOwnedSlice(allocator);
}

fn enumerateRecursive(
    allocator: std.mem.Allocator,
    block: GenerateBlock,
    remaining: []const InputDecl,
    var_map: *std.StringHashMap(i64),
    const_map: std.StringHashMap(i64),
    entries: *std.ArrayListUnmanaged(TableEntry),
) !void {
    if (remaining.len == 0) {
        // all inputs bound — evaluate expression
        const result = try eval(block.expr, var_map.*, const_map);
        const clamped = @max(block.output_min,
                             @min(block.output_max, result));

        // build key: one digit per input in declaration order
        var key_buf: std.ArrayListUnmanaged(u8) = .empty;
        for (block.inputs) |inp| {
            const val = var_map.get(inp.name) orelse 0;
            // represent as decimal digit(s)
            const digit = try std.fmt.allocPrint(allocator, "{d}", .{val});
            try key_buf.appendSlice(allocator, digit);
            allocator.free(digit);
        }
        try entries.append(allocator, .{
            .key = try key_buf.toOwnedSlice(allocator),
            .value = clamped,
        });
        return;
    }

    const inp = remaining[0];
    var v = inp.min;
    while (v <= inp.max) : (v += 1) {
        try var_map.put(inp.name, v);
        try enumerateRecursive(
            allocator,
            block,
            remaining[1..],
            var_map,
            const_map,
            entries,
        );
    }
}