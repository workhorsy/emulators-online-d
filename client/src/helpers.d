// Copyright (c) 2015-2018 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
// emulators-online is a HTML based front end for video game console emulators
// It uses the GNU AGPL 3 license
// It is hosted at: https://github.com/workhorsy/emulators-online-d
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.


module helpers;

//import std.stdio;

int g_direct_x_version = -1;

string SanitizeFileName(string name) {
	import std.string : replace;
	import std.algorithm.mutation : strip;

	// Replace all the chars with the safe equiv
	const string[string] sanitize_map = [
		"/" : "+",
		"\\" : "+",
		": " : " - ",
		"*" : "+",
		"?" : "",
		"\"" : "'",
		"<" : "[",
		">" : "]",
		"|" : "+",
	];
	foreach (before, after ; sanitize_map) {
		name = name.replace(before, after);
	}

	// Remove any trailing periods
	name = strip(name, '.');

	return name;
}

string CleanPath(string file_path) {
	import std.string : replace, endsWith, split;
	import std.algorithm : canFind;

	// Fix the backward slashes from Windows
	string new_path = file_path.replace("\\", "/");

	// Strip off the Disc number
	if (new_path.canFind(" [Disc")) {
		new_path = new_path.split(" [Disc")[0];
	}

	// Make sure it ends with a slash
	if (! new_path.endsWith("/")) {
		new_path ~= "/";
	}

	return new_path;
}

string[] glob(string path, string pattern, bool is_shallow) {
	import std.file : dirEntries, isDir, SpanMode;
	import std.path : baseName, globMatch;
	import std.range.primitives : popFront;
	//import std.stdio;

	string[] matches;
	string[] to_search = [path];
	while (to_search.length > 0) {
		string current = to_search[0];
		popFront(to_search);
		try {
			auto entries = dirEntries(current, SpanMode.shallow);
			foreach (entry ; entries) {
				if (! is_shallow && isDir(entry.name)) {
					to_search ~= entry.name;
				} else {
					string base_name = baseName(entry.name);
					if (globMatch(base_name, pattern)) {
						matches ~= entry.name;
					}
				}
			}
		} catch (Throwable err) {

		}
	}


	return matches;
}

void TryRemovingFileOnExit(string file_name) {
	import std.file : exists, remove, FileException;

	if (exists(file_name)) {
		try {
			remove(file_name);
		} catch (FileException err) {
			// Ignore any error
		}
	}
};

int GetDirectxVersion() {
	int int_version = -1;

	version (Windows) {
		import std.process : pipeProcess, wait, Redirect;
		import std.file : read;
		import std.stdio : stderr;
		import std.string : split, indexOf;

		// Try to remove any generated files when the function exists
		scope (exit) TryRemovingFileOnExit("directx_info.txt");

		const string[] command = [
			"dxdiag.exe",
			"/t",
			"directx_info.txt",
		];

		// Run the command and wait for it to complete
		auto pipes = pipeProcess(command, Redirect.stdout | Redirect.stderr);
		int status = wait(pipes.pid);

		if (status != 0) {
			stderr.writefln("Failed to determine DirectX version"); stderr.flush();
		}

		string string_data = cast(string) read("directx_info.txt");
		string raw_version = string_data.split("DirectX Version: ")[1].split("\r\n")[0];

		// Get the DirectX version
		if (raw_version.indexOf("12") != -1) {
			int_version = 12;
		} else if (raw_version.indexOf("11") != -1) {
			int_version = 11;
		} else if (raw_version.indexOf("10") != -1) {
			int_version = 10;
		} else if (raw_version.indexOf("9") != -1) {
			int_version = 9;
		} else {
			stderr.writefln("Failed to determine DirectX version"); stderr.flush();
		}
	}

	return int_version;
}
