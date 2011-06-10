module dlinq.generator;

import core.thread;

// Grab from:
// https://github.com/pszturmaj/dgenerators/blob/master/generators.d
void __yield(alias var)(typeof(var) value) {
    static assert(__traits(isOut, var), "Yield works only with OUT arguments");
    auto fiber = Fiber.getThis();
    if (!fiber) return;
    var = value;
    Fiber.yield();
}

class Generator(Type) : Fiber {
	Type value;
	void delegate(out Type result) dg;

	public this(typeof(dg) dg) {
		this.dg = dg;
		super(&fiberMain);
	}
	
	@property bool empty() {
		return state == State.TERM;
	}
	
	void popFront() {
		call();
	}
	
	@property pure nothrow Type front() {
		return value;
	}
	
	void fiberMain() {
		dg(value);
	}
	
	static public Generator!Type opCall(void delegate(out Type result) dg) {
		return new Generator!Type(dg);
	}
}

string generator(Type, string t)() {
	//mixin("delegate (out uint result) {" ~ t ~ "}");
	return (
		"return Generator!uint(delegate (out " ~ Type.stringof ~ " result) { " ~
			"void yield(" ~ Type.stringof ~ " v) { __yield!result(v); }" ~
			t ~
		"});"
	);
}

auto limit(Type)(Generator!Type parentGenerator, int count) {
	mixin(generator!(Type, q{
		foreach (v; parentGenerator) {
			yield(v);
			if (count-- <= 0) break;
		}
	}));
}

auto positiveNumbers() {
	mixin(generator!(uint, q{
		uint n = 0;
		while (true) {
			yield(++n);
		}
	}));
}