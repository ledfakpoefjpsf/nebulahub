-- This file was protected using slimeobf Obfuscator v1

local A = "FDNXLcJw0ebI+a6xZyqdBPrRvh7OjKWofzkGpgl52/M38CstmS1i4YUT9QnEAVHu"

local K1, K2, K3 = 30111, 22282, 269
local SIG = 1070297603

local bit = bit32
local sbyte, schar, sfmt = string.byte, string.char, string.format
local tostr = tostring

local D = {}
for i = 1, 64 do
	D[sbyte(A, i)] = i - 1
end

local function d64(s)
	local out = {}
	local o = 0
	local i = 1
	local n = #s
	while i <= n do
		local c1 = D[sbyte(s, i)]
		local c2 = D[sbyte(s, i + 1)]
		local c3 = D[sbyte(s, i + 2)]
		local c4 = D[sbyte(s, i + 3)]
		local v = ((c1 * 64 + c2) * 64 + (c3 or 0)) * 64 + (c4 or 0)
		o = o + 1
		out[o] = schar((v - v % 65536) / 65536)
		if c3 then
			o = o + 1
			out[o] = schar((v - v % 256) / 256 % 256)
		end
		if c4 then
			o = o + 1
			out[o] = schar(v % 256)
		end
		i = i + 4
	end
	return table.concat(out)
end

local raw = d64(B)
local n = #raw
local seed = bit.band(K1 + K2 * 65536 + K3 * 4096, 4294967295)
local s = seed
local acc = 0
if not buffer then
	error("unsupported environment")
end
local enc = buffer.create(n)
for i = 1, n do
	s = bit.bxor(s, bit.band(bit.lshift(s, 13), 4294967295))
	s = bit.bxor(s, bit.rshift(s, 17))
	s = bit.bxor(s, bit.band(bit.lshift(s, 5), 4294967295))
	local b = bit.bxor(sbyte(raw, i), s % 256)
	buffer.writeu8(enc, i - 1, b)
	acc = bit.band(acc + b * (i % 251 + 1), 4294967295)
end
if acc ~= bit.bxor(SIG, seed) then
	return
end

local function unlz4(src, start, len, size)
	local dst = buffer.create(size)
	local dp = 0
	local i = start
	local stop = start + len
	while i < stop do
		local token = buffer.readu8(src, i)
		i = i + 1
		local lit = math.floor(token / 16)
		if lit == 15 then
			while true do
				local b = buffer.readu8(src, i)
				i = i + 1
				lit = lit + b
				if b ~= 255 then
					break
				end
			end
		end
		if lit > 0 then
			buffer.copy(dst, dp, src, i, lit)
			dp = dp + lit
			i = i + lit
		end
		if i >= stop then
			break
		end
		local off = buffer.readu8(src, i) + buffer.readu8(src, i + 1) * 256
		i = i + 2
		local ml = token % 16
		if ml == 15 then
			while true do
				local b = buffer.readu8(src, i)
				i = i + 1
				ml = ml + b
				if b ~= 255 then
					break
				end
			end
		end
		ml = ml + 4
		if ml <= off then
			buffer.copy(dst, dp, dst, dp - off, ml)
			dp = dp + ml
		else
			local pat = buffer.readstring(dst, dp - off, off)
			local rep = string.rep(pat, math.floor((ml + off - 1) / off))
			buffer.writestring(dst, dp, string.sub(rep, 1, ml))
			dp = dp + ml
		end
	end
	return dst
end

local usize = buffer.readu32(enc, 0)
local buf = unlz4(enc, 4, n - 4, usize)
local bp = 0

local np = buffer.readu32(buf, 1)
local flags = buffer.readu8(buf, 0)
local wide = bit.band(flags, 1) ~= 0
local haslines = bit.band(flags, 2) ~= 0
bp = 5
local P = {}
for pi = 0, np - 1 do
	local p = {}
	p.np = buffer.readu8(buf, bp)
	bp = bp + 1
	p.v = buffer.readu8(buf, bp) ~= 0
	bp = bp + 1
	p.nl = buffer.readu16(buf, bp)
	bp = bp + 2
	local cl = buffer.readu32(buf, bp)
	bp = bp + 4
	local c = table.create(cl * 4)
	if wide then
		for k = 0, cl - 1 do
			local o = k * 4
			c[o] = buffer.readu8(buf, bp)
			c[o + 1] = buffer.readi32(buf, bp + 1)
			c[o + 2] = buffer.readi32(buf, bp + 5)
			c[o + 3] = buffer.readi32(buf, bp + 9)
			bp = bp + 13
		end
	else
		for k = 0, cl - 1 do
			local o = k * 4
			c[o] = buffer.readu8(buf, bp)
			c[o + 1] = buffer.readi16(buf, bp + 1)
			c[o + 2] = buffer.readi16(buf, bp + 3)
			c[o + 3] = buffer.readi16(buf, bp + 5)
			bp = bp + 7
		end
	end
	p.c = c
	p.cn = cl
	if haslines then
		local L = table.create(cl)
		for k = 0, cl - 1 do
			L[k] = buffer.readu16(buf, bp)
			bp = bp + 2
		end
		p.lines = L
	end
	local kl = buffer.readu32(buf, bp)
	bp = bp + 4
	local K = table.create(kl)
	for ki = 0, kl - 1 do
		local tag = buffer.readu8(buf, bp)
		bp = bp + 1
		if tag == 3 then
			K[ki] = buffer.readf64(buf, bp)
			bp = bp + 8
		elseif tag == 4 then
			local l = buffer.readu32(buf, bp)
			bp = bp + 4
			K[ki] = buffer.readstring(buf, bp, l)
			bp = bp + l
		elseif tag == 5 then
			K[ki] = buffer.readu32(buf, bp)
			bp = bp + 4
		elseif tag == 1 then
			K[ki] = false
		elseif tag == 2 then
			K[ki] = true
		end
	end
	p.K = K
	p.kn = kl
	p.id = pi
	local nu = buffer.readu8(buf, bp)
	bp = bp + 1
	local u = {}
	for j = 1, nu do
		local flag = buffer.readu8(buf, bp)
		local idx = buffer.readu16(buf, bp + 1)
		u[j] = {flag ~= 0, idx}
		bp = bp + 3
	end
	p.u = u
	P[pi] = p
end

local G = (getfenv and getfenv()) or _G
local exec, mk
local DBG_LINE = 0
local DBG_PROTO = 0
local DBG_PC = 0
local H = {}

H[65] = function(st, i)
	return i + 4
end

H[34] = function(st, i)
	local c, S = st.c, st.S
	local sp = st.sp
	for k = 1, c[i + 1] do
		S[sp] = nil
		sp = sp + 1
	end
	st.sp = sp
	return i + 4
end

H[38] = function(st, i)
	local sp = st.sp
	st.S[sp] = st.c[i + 1] ~= 0
	st.sp = sp + 1
	return i + 4
end

H[3] = function(st, i)
	local sp = st.sp
	st.S[sp] = st.K[st.c[i + 1]]
	st.sp = sp + 1
	return i + 4
end

H[5] = function(st, i)
	local sp = st.sp
	st.S[sp] = st.K[st.c[i + 1]]
	st.sp = sp + 1
	return i + 4
end

H[18] = function(st, i)
	st.sp = st.sp - st.c[i + 1]
	return i + 4
end

H[47] = function(st, i)
	local sp = st.sp
	st.S[sp] = st.S[sp - 1]
	st.sp = sp + 1
	return i + 4
end

H[67] = function(st, i)
	local c, S = st.c, st.S
	local m = c[i + 1]
	local sp = st.sp
	for k = 1, m do
		S[sp] = S[sp - m]
		sp = sp + 1
	end
	st.sp = sp
	return i + 4
end

H[59] = function(st, i)
	local sp = st.sp
	local S = st.S
	S[sp - 1], S[sp - 2] = S[sp - 2], S[sp - 1]
	return i + 4
end

H[58] = function(st, i)
	local sp = st.sp
	st.S[sp] = st.S[st.c[i + 1]]
	st.sp = sp + 1
	return i + 4
end

H[63] = function(st, i)
	local sp = st.sp - 1
	st.S[st.c[i + 1]] = st.S[sp]
	st.sp = sp
	return i + 4
end

H[55] = function(st, i)
	local c = st.c
	st.S[c[i + 1]] = st.S[c[i + 2]]
	return i + 4
end

H[16] = function(st, i)
	local sp = st.sp
	st.S[sp] = st.S[st.c[i + 1]].v
	st.sp = sp + 1
	return i + 4
end

H[37] = function(st, i)
	local sp = st.sp - 1
	st.S[st.c[i + 1]].v = st.S[sp]
	st.sp = sp
	return i + 4
end

H[43] = function(st, i)
	local c = st.c
	st.S[c[i + 1]].v = st.S[c[i + 2]]
	return i + 4
end

H[68] = function(st, i)
	local k = st.c[i + 1]
	st.S[k] = {v = st.S[k]}
	return i + 4
end

H[62] = function(st, i)
	local sp = st.sp - 1
	st.S[st.c[i + 1]] = {v = st.S[sp]}
	st.sp = sp
	return i + 4
end

H[61] = function(st, i)
	local c = st.c
	st.S[c[i + 1]] = {v = st.S[c[i + 2]]}
	return i + 4
end

H[48] = function(st, i)
	st.S[st.c[i + 1]] = {v = nil}
	return i + 4
end

H[64] = function(st, i)
	local sp = st.sp
	st.S[sp] = G[st.K[st.c[i + 1]]]
	st.sp = sp + 1
	return i + 4
end

H[22] = function(st, i)
	local sp = st.sp - 1
	G[st.K[st.c[i + 1]]] = st.S[sp]
	st.sp = sp
	return i + 4
end

H[44] = function(st, i)
	local c = st.c
	G[st.K[c[i + 1]]] = st.S[c[i + 2]]
	return i + 4
end

H[23] = function(st, i)
	local sp = st.sp
	st.S[sp] = st.up[st.c[i + 1]].v
	st.sp = sp + 1
	return i + 4
end

H[54] = function(st, i)
	local sp = st.sp - 1
	st.up[st.c[i + 1]].v = st.S[sp]
	st.sp = sp
	return i + 4
end

H[12] = function(st, i)
	local c = st.c
	st.up[c[i + 1]].v = st.S[c[i + 2]]
	return i + 4
end

H[35] = function(st, i)
	local sp = st.sp
	local o = st.S[sp - 2]
	st.S[sp - 2] = o[st.S[sp - 1]]
	st.sp = sp - 1
	return i + 4
end

H[9] = function(st, i)
	local sp = st.sp
	local o = st.S[sp - 3]
	o[st.S[sp - 2]] = st.S[sp - 1]
	st.sp = sp - 3
	return i + 4
end

H[49] = function(st, i)
	local c = st.c
	st.S[c[i + 1]][st.S[c[i + 2]]] = st.S[c[i + 3]]
	return i + 4
end

H[28] = function(st, i)
	local sp = st.sp
	st.S[sp] = {}
	st.sp = sp + 1
	return i + 4
end

H[10] = function(st, i)
	local d = st.c[i + 1]
	local S = st.S
	local sp = st.sp
	local t = S[d]
	local m = #t
	for j = d + 1, sp - 1 do
		m = m + 1
		t[m] = S[j]
	end
	st.sp = d + 1
	return i + 4
end

local function arith(f)
	return function(st, i)
		local sp = st.sp
		local S = st.S
		S[sp - 2] = f(S[sp - 2], S[sp - 1])
		st.sp = sp - 1
		return i + 4
	end
end

H[57] = arith(function(a, b) return a + b end)
H[41] = arith(function(a, b) return a - b end)
H[7] = arith(function(a, b) return a * b end)
H[60] = arith(function(a, b) return a / b end)
H[52] = arith(function(a, b) return a % b end)
H[11] = arith(function(a, b) return a ^ b end)
H[27] = arith(function(a, b) return a // b end)

H[29] = function(st, i)
	local m = st.c[i + 1]
	local S = st.S
	local sp = st.sp
	local k = sp - m
	local accv = S[k]
	for j = k + 1, sp - 1 do
		accv = accv .. S[j]
	end
	S[k] = accv
	st.sp = k + 1
	return i + 4
end

H[33] = function(st, i)
	local sp = st.sp
	st.S[sp - 1] = tostr(st.S[sp - 1])
	return i + 4
end

H[32] = function(st, i)
	local sp = st.sp
	st.S[sp - 1] = -st.S[sp - 1]
	return i + 4
end

H[51] = function(st, i)
	local sp = st.sp
	st.S[sp - 1] = not st.S[sp - 1]
	return i + 4
end

H[8] = function(st, i)
	local sp = st.sp
	st.S[sp - 1] = #st.S[sp - 1]
	return i + 4
end

H[45] = arith(function(a, b) return bit.band(a, b) end)
H[56] = arith(function(a, b) return bit.bor(a, b) end)
H[53] = arith(function(a, b) return bit.bxor(a, b) end)
H[2] = arith(function(a, b) return bit.lshift(a, b) end)
H[13] = arith(function(a, b) return bit.rshift(a, b) end)

H[21] = function(st, i)
	local sp = st.sp
	st.S[sp - 1] = bit.bnot(st.S[sp - 1])
	return i + 4
end

H[36] = arith(function(a, b) return a == b end)
H[19] = arith(function(a, b) return a < b end)
H[4] = arith(function(a, b) return a <= b end)
H[66] = arith(function(a, b) return a > b end)
H[25] = arith(function(a, b) return a >= b end)

H[39] = function(st, i)
	return st.c[i + 1] * 4
end

H[1] = function(st, i)
	local sp = st.sp - 1
	local v = st.S[sp]
	st.sp = sp
	if not v then
		return st.c[i + 1] * 4
	end
	return i + 4
end

H[42] = function(st, i)
	local sp = st.sp - 1
	local v = st.S[sp]
	st.sp = sp
	if v then
		return st.c[i + 1] * 4
	end
	return i + 4
end

H[20] = function(st, i)
	if st.S[st.c[i + 1]] == nil then
		return st.c[i + 2] * 4
	end
	return i + 4
end

H[17] = function(st, i)
	local c = st.c
	local fd = c[i + 3]
	local na = c[i + 1]
	if na < 0 then
		na = st.sp - fd - 1
	end
	local fn = st.S[fd]
	if type(fn) ~= "function" and type(fn) ~= "table" then
		error("attempt to call a " .. type(fn) .. " value", 0)
	end
	local nr = c[i + 2]
	local S = st.S
	if nr == 1 then
		S[fd] = fn(table.unpack(S, fd + 1, fd + na))
		st.sp = fd + 1
		return i + 4
	elseif nr == 0 then
		fn(table.unpack(S, fd + 1, fd + na))
		st.sp = fd
		return i + 4
	end
	local R
	if type(fn) == "function" then
		R = table.pack(fn(table.unpack(S, fd + 1, fd + na)))
	else
		local mt = getmetatable(fn)
		local callable = mt and mt.__call
		if not callable then
			error("attempt to call a table value", 0)
		end
		local args = table.create(na + 1)
		args[1] = fn
		for j = 1, na do
			args[j + 1] = S[fd + j]
		end
		R = table.pack(callable(table.unpack(args, 1, na + 1)))
	end
	if nr > 0 then
		for j = 1, nr do
			S[fd + j - 1] = R[j]
		end
		st.sp = fd + nr
	else
		for j = 1, R.n do
			S[fd + j - 1] = R[j]
		end
		st.sp = fd + R.n
	end
	return i + 4
end

H[46] = function(st, i)
	local a = st.c[i + 1]
	local from = st.c[i + 2]
	local m = a
	if a < 0 then
		m = st.sp - from
	end
	st.rs = from
	st.rn = m
	return -1
end

H[31] = function(st, i)
	local p = P[st.K[st.c[i + 1]]]
	local ups = {}
	local u = p.u
	for j = 1, #u do
		local d = u[j]
		if d[1] then
			ups[j - 1] = st.S[d[2]]
		else
			ups[j - 1] = st.up[d[2]]
		end
	end
	local sp = st.sp
	st.S[sp] = mk(p, ups)
	st.sp = sp + 1
	return i + 4
end

H[15] = function(st, i)
	local c = st.c
	local p = P[st.K[c[i + 1]]]
	local dst = c[i + 2]
	local ups = {}
	local u = p.u
	for j = 1, #u do
		local d = u[j]
		if d[1] then
			ups[j - 1] = st.S[d[2]]
		else
			ups[j - 1] = st.up[d[2]]
		end
	end
	local cl = mk(p, ups)
	if c[i + 3] ~= 0 then
		st.S[dst].v = cl
	else
		st.S[dst] = cl
	end
	st.sp = dst + 1
	return i + 4
end

H[6] = function(st, i)
	local m = st.c[i + 1]
	local va = st.va
	local sp = st.sp
	local S = st.S
	if m < 0 then
		m = va.n
	end
	for j = 1, m do
		S[sp] = va[j]
		sp = sp + 1
	end
	st.sp = sp
	return i + 4
end

H[14] = function(st, i)
	st.sp = st.c[i + 1]
	return i + 4
end

H[0] = function(st, i) return i + 4 end
H[50] = function(st, i) return i + 4 end
H[24] = function(st, i) return i + 4 end
H[30] = function(st, i) return i + 4 end
H[40] = function(st, i) return i + 4 end
H[69] = function(st, i) return i + 4 end
H[26] = function(st, i) return i + 4 end

exec = function(p, ups, ...)
	local S = {}
	local n = select("#", ...)
	if n == 1 then
		S[0] = ...
	elseif n == 2 then
		S[0], S[1] = ...
	elseif n == 3 then
		S[0], S[1], S[2] = ...
	elseif n == 4 then
		S[0], S[1], S[2], S[3] = ...
	elseif n > 4 then
		for j = 1, n do
			S[j - 1] = select(j, ...)
		end
	end
	local va
	if p.v then
		local extra = n - p.np
		if extra < 0 then
			extra = 0
		end
		va = {n = extra}
		for j = 1, extra do
			va[j] = S[p.np + j - 1]
		end
	end
	local st = {
		S = S, sp = p.np, K = p.K, c = p.c, up = ups, va = va,
		rn = 0, rs = 0,
	}
	local i = 0
	local c = p.c
	local K = p.K
	local sp = st.sp
	local canary = c[0]
	local tick = 250000
	local dbg = p.lines
	while true do
		local op = c[i]
		if op == 58 then
			S[sp] = S[c[i + 1]]
			sp = sp + 1
			i = i + 4
		elseif op == 3 then
			S[sp] = K[c[i + 1]]
			sp = sp + 1
			i = i + 4
		elseif op == 5 then
			S[sp] = K[c[i + 1]]
			sp = sp + 1
			i = i + 4
		elseif op == 64 then
			S[sp] = G[K[c[i + 1]]]
			sp = sp + 1
			i = i + 4
		elseif op == 63 then
			sp = sp - 1
			S[c[i + 1]] = S[sp]
			i = i + 4
		elseif op == 14 then
			sp = c[i + 1]
			i = i + 4
		elseif op == 47 then
			S[sp] = S[sp - 1]
			sp = sp + 1
			i = i + 4
		elseif op == 57 then
			sp = sp - 1
			S[sp - 1] = S[sp - 1] + S[sp]
			i = i + 4
		elseif op == 1 then
			sp = sp - 1
			if not S[sp] then
				i = c[i + 1] * 4
			else
				i = i + 4
			end
		elseif op == 39 then
			i = c[i + 1] * 4
		elseif op == 35 then
			if dbg then
				local k = i / 4
				DBG_LINE = dbg[k]
				DBG_PROTO = p.id
				DBG_PC = k
			end
			sp = sp - 1
			local o = S[sp - 1]
			S[sp - 1] = o[S[sp]]
			i = i + 4
		elseif op == 9 then
			if dbg then
				local k = i / 4
				DBG_LINE = dbg[k]
				DBG_PROTO = p.id
				DBG_PC = k
			end
			sp = sp - 3
			S[sp][S[sp + 1]] = S[sp + 2]
			i = i + 4
		elseif op == 16 then
			S[sp] = S[c[i + 1]].v
			sp = sp + 1
			i = i + 4
		elseif op == 19 then
			sp = sp - 1
			S[sp - 1] = S[sp - 1] < S[sp]
			i = i + 4
		elseif op == 4 then
			sp = sp - 1
			S[sp - 1] = S[sp - 1] <= S[sp]
			i = i + 4
		elseif op == 36 then
			sp = sp - 1
			S[sp - 1] = S[sp - 1] == S[sp]
			i = i + 4
		elseif op == 42 then
			sp = sp - 1
			if S[sp] then
				i = c[i + 1] * 4
			else
				i = i + 4
			end
		elseif op == 55 then
			S[c[i + 1]] = S[c[i + 2]]
			i = i + 4
		elseif op == 18 then
			sp = sp - c[i + 1]
			i = i + 4
		else
			if dbg then
				local k = i / 4
				DBG_LINE = dbg[k]
				DBG_PROTO = p.id
				DBG_PC = k
			end
			st.sp = sp
			i = H[op](st, i)
			sp = st.sp
			if i < 0 then break end
			tick = tick - 1
			if tick <= 0 then
				tick = 250000
				if c[0] ~= canary then
					return
				end
			end
		end
	end
	if st.rn == 0 then
		return
	end
	if st.rn == 1 then
		return S[st.rs]
	end
	return table.unpack(S, st.rs, st.rs + st.rn - 1)
end

mk = function(p, ups)
	return function(...)
		return exec(p, ups, ...)
	end
end

if P[0].lines then
	local function run(...)
		return mk(P[0], {})(...)
	end
	local r = table.pack(pcall(run, ...))
	if not r[1] then
		local names = {}
		local seen = {}
		local pr = P[DBG_PROTO]
		if pr then
			local first = DBG_PC - 8
			if first < 0 then
				first = 0
			end
			local last = DBG_PC + 8
			if last > pr.cn - 1 then
				last = pr.cn - 1
			end
			for pc = first, last do
				local base = pc * 4
				for j = 0, 3 do
					local idx = pr.c[base + j]
					if type(idx) == "number" then
						local v = pr.K[idx]
						if type(v) == "string" and #v > 1 and #v <= 40 and not seen[v] then
							seen[v] = true
							names[#names + 1] = v
						end
					end
				end
			end
		end
		local msg = "[slimeobf] runtime error: " .. tostring(r[2])
			.. "\n[slimeobf] original source line: " .. tostring(DBG_LINE)
			.. "\n[slimeobf] proto: " .. tostring(DBG_PROTO) .. "  pc: " .. tostring(DBG_PC)
			.. "\n[slimeobf] constants: " .. table.concat(names, " | ")
		print(msg)
		pcall(function()
			if setclipboard then
				setclipboard(msg)
			end
		end)
		pcall(function()
			if writefile then
				writefile("slimeobf_error.txt", msg)
			end
		end)
		error(tostring(r[2]) .. "  [slimeobf line " .. tostring(DBG_LINE)
			.. " | proto " .. tostring(DBG_PROTO) .. " | pc " .. tostring(DBG_PC)
			.. " | " .. table.concat(names, ",") .. "]", 0)
	end
	return table.unpack(r, 2, r.n)
end

return mk(P[0], {})(...)

