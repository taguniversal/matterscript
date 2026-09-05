const std = @import("std");
pub const core = @import("core.zig");
pub const network: type = @import("../network.zig");

    
    // ----------------------------------------------------------------
    // IL source-fill expression parser (composition refs like $a$b())
    // ----------------------------------------------------------------

    pub fn parseILExpr(p: *core.Parser) ![]const u8 {
        p.skipWhitespaceAndComments();
        p.last_expr = null;
        const start = p.pos;
        if (p.pos < p.src.len and
            (std.ascii.isAlphanumeric(p.src[p.pos]) or p.src[p.pos] == '_'))
        {
            const saved = p.pos;
            const name = try p.readName();
            p.skipWhitespaceAndComments();
            if (p.peek() == '(') {
                _ = p.advance();
                var args: std.ArrayListUnmanaged(*network.Expr) = .empty;
                p.skipWhitespaceAndComments();
                while (p.peek() != ')' and p.peek() != null) {
                    const arg = try parseILCallArgument(p);
                    try args.append(p.allocator, arg);
                    p.skipWhitespaceAndComments();
                    _ = p.tryConsume(',');
                    p.skipWhitespaceAndComments();
                }
                try p.expect(')');
                const call = try p.allocator.create(network.Expr);
                call.* = .{
                    .kind = .call,
                    .func = name,
                    .args = try args.toOwnedSlice(p.allocator),
                };
                p.last_expr = call;
                return p.src[start..p.pos];
            }
            p.pos = saved;
        }
        while (p.peek() == '$') {
            _ = p.advance();
            _ = try p.readName();
        }
        p.skipWhitespaceAndComments();
        if (p.peek() == '(') {
            _ = p.advance();
            try p.expect(')');
        }
        if (p.pos == start) {
            // No $-composition present. Try a plain literal token
            // (e.g. "init< 0 >"); if there isn't one either — the
            // content is genuinely empty, "<>" — that's valid too
            // (an unnamed/empty fill, §12.3.4), so don't error.
            if (p.pos < p.src.len and
                (std.ascii.isAlphanumeric(p.src[p.pos]) or p.src[p.pos] == '_'))
            {
                _ = try p.readName();
            }
        }
        return p.src[start..p.pos];
    }
    
    
    const GenExprError = core.ParseError ||
        std.mem.Allocator.Error ||
        error{ Overflow, InvalidCharacter };


    fn parseGenExpr(p: *core.Parser) GenExprError!*network.Expr {
        return p.parseGenAddSub();
    }

    
    // ----------------------------------------------------------------
    // Generate block expression parser (arithmetic AST)
    // ----------------------------------------------------------------

    
    fn parseGenAddSub(p: *core.Parser) GenExprError!*network.Expr {
        var left = try p.parseGenMulDiv();
        while (true) {
            p.skipWhitespaceAndComments();
            const op: network.BinaryOp = if (p.peek() == '+') .add else if (p.peek() == '-') .sub else break;
            _ = p.advance();
            const right = try p.parseGenMulDiv();
            const node = try p.allocator.create(network.Expr);
            node.* = .{ .kind = .binary, .op = op, .left = left, .right = right };
            left = node;
        }
        return left;
    }

    fn parseGenMulDiv(p: *core.Parser) GenExprError!*network.Expr {
        var left = try p.parseGenAtom();
        while (true) {
            p.skipWhitespaceAndComments();
            const op: network.BinaryOp = if (p.peek() == '*') .mul else if (p.peek() == '/') .div else break;
            _ = p.advance();
            const right = try p.parseGenAtom();
            const node = try p.allocator.create(network.Expr);
            node.* = .{ .kind = .binary, .op = op, .left = left, .right = right };
            left = node;
        }
        return left;
    }

    fn parseGenAtom(p: *core.Parser) GenExprError!*network.Expr {
        p.skipWhitespaceAndComments();

        if (p.peek() == '(') {
            _ = p.advance();
            const inner = try p.parseGenExpr();
            try p.expect(')');
            return inner;
        }

        if (p.peek() == '$') {
            _ = p.advance();
            const name = try p.readName();
            const node = try p.allocator.create(network.Expr);
            node.* = .{ .kind = .variable, .name = name };
            return node;
        }

        if (p.peek() == '-') {
            const val = try p.readInteger();
            const node = try p.allocator.create(network.Expr);
            node.* = .{ .kind = .integer, .int_val = val };
            return node;
        }

        if (p.pos < p.src.len and std.ascii.isDigit(p.src[p.pos])) {
            const val = try p.readInteger();
            const node = try p.allocator.create(network.Expr);
            node.* = .{ .kind = .integer, .int_val = val };
            return node;
        }

        const name = try p.readName();
        p.skipWhitespaceAndComments();
        if (p.peek() == '(') {
            _ = p.advance();
            var args: std.ArrayListUnmanaged(*network.Expr) = .empty;
            p.skipWhitespaceAndComments();
            while (p.peek() != ')' and p.peek() != null) {
                const arg = try p.parseGenExpr();
                try args.append(p.allocator, arg);
                p.skipWhitespaceAndComments();
                _ = p.tryConsume(',');
                p.skipWhitespaceAndComments();
            }
            try p.expect(')');
            const node = try p.allocator.create(network.Expr);
            node.* = .{
                .kind = .call,
                .func = name,
                .args = try args.toOwnedSlice(p.allocator),
            };
            return node;
        }

        const node = try p.allocator.create(network.Expr);
        node.* = .{ .kind = .constant, .name = name };
        return node;
    }


    // parses arguments specifically for IL invocation/composition
    // calls (like nested function calls in source fills, e.g., loop(edge($p0, $p1), ...)).
    pub fn parseILCallArgument(p: *core.Parser) !*network.Expr {
        p.skipWhitespaceAndComments();

        // 1. Variable references ($var)
        if (p.peek() == '$') {
            _ = p.advance();
            const name = try p.readName();
            const node = try p.allocator.create(network.Expr);
            node.* = .{ .kind = .variable, .name = name };
            return node;
        }

        // 2. Numeric literals (integers, floats, negative values)
        const start = p.pos;
        if (p.peek() == '-') _ = p.advance();
        if (p.pos < p.src.len and (std.ascii.isDigit(p.src[p.pos]) or p.src[p.pos] == '.')) {
            while (p.pos < p.src.len and (std.ascii.isDigit(p.src[p.pos]) or p.src[p.pos] == '.')) {
                p.pos += 1;
            }
            const val_str = p.src[start..p.pos];
            const node = try p.allocator.create(network.Expr);
            node.* = .{ .kind = .constant, .name = val_str };
            return node;
        }

        // 3. Standard identifiers, or a nested call expression like
        // "loop(edge($p0, $p1), ...)" when the identifier is
        // immediately followed by '(' — mirrors the top-level call
        // parsing in parseILExpr so calls can nest arbitrarily deep
        // as arguments (e.g. face(loop(edge(...), edge(...)))).
        const name = try p.readName();
        p.skipWhitespaceAndComments();
        if (p.peek() == '(') {
            _ = p.advance();
            var args: std.ArrayListUnmanaged(*network.Expr) = .empty;
            p.skipWhitespaceAndComments();
            while (p.peek() != ')' and p.peek() != null) {
                const arg = try parseILCallArgument(p);
                try args.append(p.allocator, arg);
                p.skipWhitespaceAndComments();
                _ = p.tryConsume(',');
                p.skipWhitespaceAndComments();
            }
            try p.expect(')');
            const node = try p.allocator.create(network.Expr);
            node.* = .{
                .kind = .call,
                .func = name,
                .args = try args.toOwnedSlice(p.allocator),
            };
            return node;
        }

        const node = try p.allocator.create(network.Expr);
        node.* = .{ .kind = .constant, .name = name };
        return node;
    }