import std.stdio;
import dlinq.generator;



void main() {
	foreach (v; limit(positiveNumbers, 100)) {
	//foreach (v; positiveNumbers) {
		writefln("%d", v);
	}
}