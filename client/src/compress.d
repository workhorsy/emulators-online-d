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

module compress;


version (linux) {
	immutable string Exe7Zip = "7za";
	immutable string ExeUnrar = "unrar";
}
version (Windows) {
	immutable string Exe7Zip = "7za.exe";
	immutable string ExeUnrar = "unrar.exe";
}

enum CompressionType {
	Zlib,
	Lzma,
}

ubyte[] ToCompressed(ubyte[] blob, CompressionType compression_type) {
	import std.stdio : stdout, stderr;
	import std.array : join;
	import std.process : spawnProcess, wait;
	import std.string : format;
	import std.file : tempDir, read, write, remove;
	import std.path : dirSeparator;
	import std.zlib : compress;

	final switch (compression_type) {
		case CompressionType.Lzma:
			string blob_file = [tempDir(), "blob"].join(dirSeparator);
			string zip_file = [tempDir(), "blob.7z"].join(dirSeparator);
/*
			stdout.writefln("blob_file; %s", blob_file);
			stdout.writefln("zip_file; %s", zip_file);
*/

			// Write the blob to file
			write(blob_file, blob);

			// Get the command and arguments
			const string[] command = [
				"tools/" ~ Exe7Zip,
				"a",
				"-t7z",
				"-m0=lzma2",
				"-mx=9",
				"%s".format(zip_file),
				"%s".format(blob_file),
			];

			// Run the command and wait for it to complete
			auto pid = spawnProcess(command);
			int status = wait(pid);
		/*
			string[] result_stdout = pipes.stdout.byLine.map!(l => l.idup).array();
			string[] result_stderr = pipes.stderr.byLine.map!(l => l.idup).array();
			stdout.writefln("!!! stdout:%s", result_stdout);
			stdout.writefln("!!! stderr:%s", result_stderr);
		*/
			if (status != 0) {
				stderr.writefln("Failed to run command: %s\r\n", Exe7Zip);
			}

			// Read the compressed blob from file
			ubyte[] file_data = cast(ubyte[]) read(zip_file);

			// Delete the temp files
			remove(blob_file);
			remove(zip_file);

			return file_data;
		case CompressionType.Zlib:
			ubyte[] zlibed_data = compress(blob, 9);
			return zlibed_data;
	}
}

ubyte[] ToCompressedBase64(T)(T thing, CompressionType compression_type) {
	import std.array : appender;
	import cbor : encodeCbor;
	import std.base64 : Base64;

	// Convert the thing to a blob
	auto buffer = appender!(ubyte[])();
	encodeCbor(buffer, thing);
	ubyte[] blob = buffer.data;

	// Compress the blob
	ubyte[] compressed_bob = ToCompressed(blob, compression_type);

	// Base64 the compressed blob
	ubyte[] base64ed_compressed_blob = cast(ubyte[]) Base64.encode(compressed_bob);

	return base64ed_compressed_blob;
}

ubyte[] FromCompressed(ubyte[] data, CompressionType compression_type) {
	import std.zlib : uncompress;

	final switch (compression_type) {
		case CompressionType.Lzma:
			return [];
		case CompressionType.Zlib:
			ubyte[] blob = cast(ubyte[]) uncompress(data);
			return blob;
	}
}

T FromCompressedBase64(T)(ubyte[] data, CompressionType compression_type) {
	import cbor : decodeCborSingle;
	import std.array : appender;
	import std.base64 : Base64;

	// UnBase64 the blob
	ubyte[] compressed_blob = cast(ubyte[]) Base64.decode(data);

	// Uncompress the blob
	ubyte[] blob = FromCompressed(compressed_blob, compression_type);

	// Convert the blob to the thing
	T thing = decodeCborSingle!T(blob);
	return thing;
}

void UncompressFiles(string[] file_names, ubyte[] compressed_blobs) {
	import std.file : write;
	import std.stdio : stdout;

	// Uncompress the file blobs
	ubyte[] blob = cast(ubyte[]) compressed_blobs;
	ubyte[][] file_blobs = FromCompressedBase64!(ubyte[][])(blob, CompressionType.Zlib);

	// Copy the blobs to files
	foreach (i, file_name ; file_names) {
		stdout.writefln("name:%s, length:%s", file_name, file_blobs[i].length);
		write(file_name, file_blobs[i]);
	}
}

void UncompressFile(string compressed_file, string out_dir) {
	import std.algorithm : map;
	import std.string : format, endsWith;
	import std.process : spawnProcess, wait;
	import std.stdio : stdout, stderr;
	//import std.array;

	string[] command;

	if (compressed_file.endsWith(".7z") || compressed_file.endsWith(".zip")) {
		// Get the command and arguments
		command = [
			Exe7Zip,
			"x",
			"-y",
			`%s`.format(compressed_file),
			"-o%s".format(out_dir),
		];
	} else if (compressed_file.endsWith(".rar")) {
		// Get the command and arguments
		command = [
			ExeUnrar,
			"x",
			"-y",
			`%s`.format(compressed_file),
			"%s".format(out_dir),
		];
	} else {
		throw new Exception("Uknown file type to uncompress: %s".format(compressed_file));
	}

	// Run the command and wait for it to complete
	auto pid = spawnProcess(command);
	int status = wait(pid);
/*
	string[] result_stdout = pipes.stdout.byLine.map!(l => l.idup).array();
	string[] result_stderr = pipes.stderr.byLine.map!(l => l.idup).array();
	stdout.writefln("!!! stdout:%s", result_stdout);
	stdout.flush();
	stdout.writefln("!!! stderr:%s", result_stderr);
	stdout.flush();
*/
	if (status != 0) {
		stderr.writefln("Failed to run command: %s", command);
	}
}
