import std.string;

int min(int a, int b) { return (a < b) ? a : b; }
int max(int a, int b) { return (a > b) ? a : b; }

class Segments {
	static class Segment {
		long l, r;
		long w() { return r - l; }
		alias w length;
		static bool intersect(Segment a, Segment b, bool strict = false) {
			return (strict
				? (a.l <  b.r && a.r >  b.l)
				: (a.l <= b.r && a.r >= b.l)
			);
		}
		bool valid() { return w >= 0; }
		static Segment opCall(long l, long r) {
			auto v = new Segment;
			v.l = l;
			v.r = r;
			return v;
		}
		int opCmp(Object o) { Segment that = cast(Segment)o;
			long r = this.l - that.l;
			if (r == 0) r = this.r - that.r;
			return r;
		}
		void grow(Segment s) {
			l = min(l, s.l);
			r = max(r, s.r);
		}
		char[] toString() { return format("(%d, %d)", l, r); }
	}
	Segment[] segments;
	void refactor() {
		segments = segments.sort;
		/*
		Segment[] ss = segments; segments = [];
		foreach (s; ss) if (s.valid) segments ~= s;
		*/
	}

	Segments opAddAssign(Segment s) {
		foreach (cs; segments) {
			if (Segment.intersect(s, cs)) {
				cs.grow(s);
				goto end;
			}
		}
		segments ~= s;

		end: refactor(); return this;
	}
	
	Segments opSubAssign(Segment s) {
		Segment[] ss;
		
		void addValid(Segment s) { if (s.valid) ss ~= s; }

		foreach (cs; segments) {
			if (Segment.intersect(s, cs)) {
				addValid(Segment(cs.l, s.l ));
				addValid(Segment(s.r , cs.r));
			} else {
				addValid(cs);
			}
		}
		segments = ss;

		end: refactor(); return this;
	}

	char[] toString() { char[] r = "Segments {\n"; foreach (s; segments) r ~= "  " ~ s.toString ~ "\n"; r ~= "}"; return r; }
}