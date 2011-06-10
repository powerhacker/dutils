import std.stdio;
import dlinq.generator;

string test1(Type, string t, string t2)() {
	return "void test(" ~ Type.stringof ~ " v) { writefln(\"%s\", v); } " ~ Type.stringof ~ " " ~ t ~ "; auto dg = { " ~ t2 ~ " }; v = dg(); return delegate() { return " ~ t ~ "; };";
}

auto test2(Type)(uint z) {
	mixin(test1!(Type, "v", q{
		//test(v);
		return z;
	}));
}

void main() {
	//foreach (v; limit(positiveNumbers, 100)) {
	foreach (v; positiveNumbers!uint) {
		writefln("%d", v);
	}
}