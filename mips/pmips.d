module pmips;

import mips_patches;
import string_utils;
import stream_aggregator;

import pmips_textsearch;
import pmips_pointersearch;
import pmips_patcher;

import std.stdio, std.c.stdio, std.string, std.stream, std.regex, std.regexp, std.zip, std.getopt;

int main(string[] args) {
	auto mmap = new StreamAggregator;
	bool showHelp = true;

	void help() {
		writefln("---------------------------------------------------------------------");
		writefln("Pointer Mips (pmips) - soywiz - 2010");
		writefln("---------------------------------------------------------------------");
		writefln("Utility for translating executable files of mips platforms.");
		writefln(" N64, PSX, PS2, PSP");
		writefln("---------------------------------------------------------------------");
		writefln("");
		writefln("Options:");
		writefln("  -map  Adds a memory map. -map FILE:START-END@MEMORY");
		writefln("");
		writefln("Operations:");
		writefln("  -t  (1) Find Text blocks and writtes to 'texts.txt'.");
		writefln("  -p  (2) Find References to text blocks defined in file 'texts.txt'.");
		writefln("  -w  (3) Write changes from 'texts.txt' using references from 'pointers.txt'.");
		writefln("");
		writefln("Examples:");
		writefln("  pmips.exe -map SLUS_006.26:800@800A0000 -t");
	}
	
	void findTextBlocks(string option) {
		//writefln("%s", option);
		auto fileName = "texts.txt";
		writef("Finding text blocks...");
		scope results = TextSearcher(mmap);
		writefln("%d found", results.length);
		writefln("Writting to '%s'...", fileName);
		scope file = new std.stream.File(fileName, FileMode.OutNew);
		foreach (result; results) {
			file.writeString(result.toString);
			file.writefln("");
			//writefln("%s", result);
		}
		file.close();		
		showHelp = false;
	}

	TextSearcher.Result[uint] extractTexts(string fileName) {
		TextSearcher.Result[uint] texts;
		writefln("Opening texts '%s'...", fileName);
		scope file = new BufferedFile(fileName);
		while (!file.eof) {
			string line = std.string.strip(cast(string)file.readLine);
			//writefln("%s", line);
			if (line.length) {
				scope matches = std.regexp.search(line, r"^([^@:]+):(\w+):'(.*)'$", "mi");
				if (matches !is null) {
					uint start = cast(uint)hexdec(matches[1]);
					uint end = start + cast(uint)hexdec(matches[2]);
					texts[start] = TextSearcher.Result(start, end, stripslashes(matches[3]));
				}
			}
		}
		return texts;
	}
	
	Patcheable[int][uint] extractPatches(string fileName) {
		Patcheable[int][uint] patches;
		uint address;
		writefln("Opening patches '%s'...", fileName);
		scope file = new BufferedFile(fileName);
		while (!file.eof) {
			string line = std.string.strip(cast(string)file.readLine);
			if (line.length) {
				// Segment.
				{
					scope matches = std.regexp.search(line, r"^([^@:\[]+):'(.*)'$", "mi");
					if (matches !is null) {
						address = cast(uint)hexdec(matches[1]);
						//writefln("%08X", address);
						//writefln("%s", line);
						//texts[cast(uint)hexdec(matches[1])] = stripslashes(matches[2]);
						continue;
					}
				}
				// Patch.
				{
					scope matches = std.regexp.search(line, r"^\s*(C|T)\[(\w+)\-(\w+)\]", "mi");
					if (matches !is null) {
						uint v0 = cast(uint)hexdec(matches[2]);
						uint v1 = cast(uint)hexdec(matches[3]);
						/*if (v0 == 0x801943A4) {
							writefln("%s:%08X-%08X", matches[1], v0, v1);
						}*/
						switch (matches[1]) {
							case "C":
								patches[address][v1] = new PatchCode(address, v0, v1, address, "");
							break;
							case "T":
								patches[address][v0] = new PatchPointer(address, v0, address, "");
							break;
						}
						continue;
						//writefln("%s", line);
						//texts[cast(uint)hexdec(matches[1])] = stripslashes(matches[2]);
					}
				}
			}
		}
		return patches;
	}
	
	void findPointers(string option) {
		auto search = new MipsPointerSearch(mmap);
		auto texts = extractTexts("texts.txt");
		writefln("Found %d texts.", texts.length);
		foreach (result; TextSearcher(mmap)) {
			if (result.start in texts) search.addAddress(result.start, result.end);
		}
		search.execute();
		//search.dump();
		scope filew = new std.stream.File("pointers.txt", FileMode.OutNew);
		foreach (address, si; search) {
			if (si.patches.length) {
				filew.writef("%08X:'", si.start);
				filew.writeString(addslashes(si.text));
				filew.writefln("'");
				foreach (patchAddress, patch; si.patches) {
					filew.writef("\t");
					filew.writeString(patch.simpleString);
					filew.writefln("");
				}
			} else {
				filew.writef("#%08X:'", address);
				filew.writeString(addslashes(si.text));
				filew.writefln("'");
				filew.writefln("\t#NOT FOUND REFERENCES!!");
			}
			filew.writefln("");
		}
		filew.close();
		showHelp = false;
	}

	void patchFile() {
		auto search  = new MipsPointerSearch(mmap);
		auto texts   = extractTexts("texts.txt");
		auto patches = extractPatches("pointers.txt");

		foreach (text; texts) {
			auto pe = new PatchEntry();
			pe.start = text.start;
			pe.end   = text.end;
			pe.text  = text.text;
			auto textAddressBase = text.start & search.valueMask;
			//writefln("%08X, %08X", patches.keys[0]);
			if (text.start in patches) {
				pe.patches = patches[text.start];
			}
			search.search[pe.start] = pe;
		}
		//writefln("%08X", patches.keys.sort[0]);
		
		MipsPointerPatch(search);
		writefln("Pached successfully");
		showHelp = false;
	}

	void addMap(string option, string value) {
		scope matches = std.regexp.search(value, r"^([^@:]+)(:([0-9a-f]*)(\-([0-9a-f]*))?)?(@([0-9a-f]+))?", "mi");
		if (matches) {
			auto file       = matches[1];
			auto file_start = hexdec(matches[3]);
			auto file_end   = hexdec(matches[5]);
			auto mem_start  = hexdec(matches[7]);
			//foreach (n; 0..8) writefln("%d: %s", n, matches[n]);
			writefln("MAP: file('%s'), file_start(0x_%08X), file_end(0x_%08X), mem_start(0x_%08X)", file, file_start, file_end, mem_start);
			string fileBack = file ~ ".bak";
			if (!std.file.exists(fileBack)) {
				writef("Backuping file '%s'->'%s'...", file, fileBack);
				std.file.copy(file, fileBack);
				writefln("Ok");
			} else {
				writef("Restoring file '%s'->'%s'...", fileBack, file);
				std.file.copy(fileBack, file);
				writefln("Ok");
			}
			
			auto stream = new std.stream.File(file, FileMode.In | FileMode.Out);
			mmap.addMap(cast(uint)mem_start, (file_end > file_start) ? (new SliceStream(stream, file_start, file_end)) : (new SliceStream(stream, file_start)));
		} else {
			writefln("MAP: Invalid format for -map option ('%s').", value);
		}
	}

	if (args.length > 1) {
		getopt(args,
			config.bundling,
			"map", &addMap,

			config.noBundling,
			"t", &findTextBlocks,
			"p", &findPointers,
			"w", &patchFile,
			"h|help", &help
		);
	} else {
		showHelp = true;
	}

	if (showHelp) {
		help();
		return -1;
	} else {
		return 0;
	}
}