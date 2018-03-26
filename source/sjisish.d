/++ SJIS encoding/decoding.
+
+	Authors: Cameron "Herringway" Ross
+	Copyright: Cameron "Herringway" Ross
+	License: Boost Software License 1.0
+/
module sjisish;

private immutable dchar[ushort] fromSJISTable;
private immutable ushort[dchar] toSJISTable;

import std.traits : isSomeString;
import std.typecons : Flag;

/++
+ Encodes an SJIS string as unicode.
+
+ Params:
+	T = Type of string to output.
+	input = Raw SJIS string to encode.
+/

auto toUTF(T = string)(const ubyte[] input) if (isSomeString!T) {
	T output;
	if (!__ctfe) {
		output.reserve(input.length);
	}

	for (int i = 0; i < input.length; i++) {
		if ((input[i] >= 0x80) && (input[i] < 0xA1)) {
			ushort chr = (input[i]<<8)+input[i+1];
			if (chr in fromSJISTable) {
				output ~= fromSJISTable[chr];
			} else {
				output ~= '\uFFFD';
			}
			i++;
		} else if ((input[i] >= 0xA1) && (input[i] < 0xE0)) {
			output ~= fromSJISTable[input[i]];
		} else if (input[i] >= 0xE0) {
			ushort chr = (input[i]<<8)+input[i+1];
			if (chr in fromSJISTable) {
				output ~= fromSJISTable[chr];
			} else {
				output ~= '\uFFFD';
			}
		} else {
			immutable char x = input[i];
			output ~= x;
		}
	}
	return output;
}
///
@safe pure unittest {
	assert(toUTF([0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x2e]) == "Hello.");
	assert(toUTF([0x82, 0x67, 0x82, 0x85, 0x82, 0x8c, 0x82, 0x8c,  0x82, 0x8f, 0x81, 0x44]) == "Ｈｅｌｌｏ．");
	assert(toUTF!dstring([0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x2e]) == "Hello."d);
	assert(toUTF!dstring([0x82, 0x67, 0x82, 0x85, 0x82, 0x8c, 0x82, 0x8c,  0x82, 0x8f, 0x81, 0x44]) == "Ｈｅｌｌｏ．"d);
	assert(toUTF!wstring([0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x2e]) == "Hello."w);
	assert(toUTF!wstring([0x82, 0x67, 0x82, 0x85, 0x82, 0x8c, 0x82, 0x8c,  0x82, 0x8f, 0x81, 0x44]) == "Ｈｅｌｌｏ．"w);
}

/// Holds an SJIS string.
struct SJISString {
	alias raw this;
	/// Raw data.
	immutable(ubyte)[] raw;

	/// Convert string to unicode.
	auto toUTF(T = string)() const {
		return raw.toUTF!T;
	}
}

/++
+ Encodes a unicode string as SJIS.
+
+ Note: Badly-formed unicode strings will always fail.
+ Params:
+	input = String to encode.
+	skipInvalidCharacters = Whether to skip characters that don't exist in SJIS or throw an exception.
+/
auto toSJIS(T)(T input, Flag!"IgnoreInvalid" skipInvalidCharacters = Flag!"IgnoreInvalid".no) if (isSomeString!T) {
	import std.exception : enforce;
	SJISString output;
	if (!__ctfe) {
		output.reserve(input.length);
	}

	foreach (dchar character; input) {
		auto sjisCharPtr = character in toSJISTable;
		if (!skipInvalidCharacters) {
			enforce(sjisCharPtr, "Illegal SJIS character detected in input.");
		}
		auto sjisChar = *sjisCharPtr;
		if (sjisChar > 0xFF) {
			output.raw ~= cast(ubyte)((sjisChar&0xFF00)>>8);
			output.raw ~= cast(ubyte)(sjisChar&0xFF);
		} else {
			output.raw ~= cast(ubyte)sjisChar;
		}
	}

	return output;
}
///
@safe pure unittest {
	assert(toSJIS("Hello.") == SJISString([0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x2e]));
	assert(toSJIS("Ｈｅｌｌｏ．") == SJISString([0x82, 0x67, 0x82, 0x85, 0x82, 0x8c, 0x82, 0x8c,  0x82, 0x8f, 0x81, 0x44]));
	assert(toSJIS("Hello."d) == SJISString([0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x2e]));
	assert(toSJIS("Ｈｅｌｌｏ．"d) == SJISString([0x82, 0x67, 0x82, 0x85, 0x82, 0x8c, 0x82, 0x8c,  0x82, 0x8f, 0x81, 0x44]));
	assert(toSJIS("Hello."w) == SJISString([0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x2e]));
	assert(toSJIS("Ｈｅｌｌｏ．"w) == SJISString([0x82, 0x67, 0x82, 0x85, 0x82, 0x8c, 0x82, 0x8c,  0x82, 0x8f, 0x81, 0x44]));
}

///Initialize character table.
shared static this() {
	import std.algorithm.iteration : splitter;
	import std.algorithm.searching : startsWith;
	import std.conv : to;
	import std.string : lineSplitter;
	auto str = import("SHIFTJIS.TXT");
	foreach (line; str.lineSplitter) {
		if (line.startsWith("#")) {
			continue;
		}
		auto split = line.splitter("\t");
		auto bytesequence = split.front[2..$].to!ushort(16);
		split.popFront();
		auto sjisChar = split.front[2..$].to!ushort(16);
		fromSJISTable[bytesequence] = sjisChar;
		toSJISTable[sjisChar] = bytesequence;
	}

}
