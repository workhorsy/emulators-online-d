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


module worker;


import std.json : JSONValue;
import vibe.vibe : WebSocket;

// g_db is accessed like g_db[console][game][binary_name]
string[string][string][string] g_db;
//long[string][string] g_file_modify_dates;

void SearchGameDirectory(ref WebSocket sock, ref JSONValue data) {
	import std.file : dirEntries, isFile, SpanMode, exists;
	import std.string : format;
	import std.path : absolutePath;
	//import std.datetime;
	import std.array : replace;
	import std.base64 : Base64;
	import std.stdio : stdout;
	import vibe.vibe : logFatal;
	import jsonizer : toJSONString;
	import helpers : SanitizeFileName, CleanPath;
	import compress : ToCompressed, CompressionType;
	import encoder : EncodeMessage;
	static import identify_dreamcast_games;
	import identify_gamecube_games : getGameCubeGameInfo;

	string directory_name = data["directory_name"].str;
	string console = data["console"].str;

	// Get the path for this console
	string path_prefix;
	switch (console) {
		case "dreamcast":
			path_prefix = "images/Sega/Dreamcast";
			break;
		case "playstation2":
			path_prefix = "images/Sony/Playstation2";
			break;
		case "gamecube":
			path_prefix = "images/Nintendo/GameCube";
			break;
		default:
			logFatal("Unknown console type: %s", console);
			return;
	}

	// Get the total number of files
	float total_files = 0.0f;
	auto entries = dirEntries(directory_name, SpanMode.breadth);
	foreach (entry ; entries) {
		if (isFile(entry)) {
			total_files++;
		}
	}

	// Walk through all the directories
	float done_files = 0.0f;
	entries = dirEntries(directory_name, SpanMode.breadth);
	foreach (file_info ; entries) {
		// Get the full path
		string entry = file_info;
		entry = absolutePath(entry);
		entry = entry.replace("\\", "/");

		// Skip if the the entry is not a file
		if (! isFile(entry)) {
			continue;
		}

		// Get the percentage of the progress looping through files
		float percentage = (done_files / total_files) * 100.0f;
		done_files += 1.0f;
/*
		// Skip if the game file has not been modified
		long old_modify_date = 0;
		if ((entry in g_file_modify_dates[console]) != null) {
			old_modify_date = g_file_modify_dates[console][entry];
		}
		auto modify_date = entry.timeLastModified().toUnixTime();
		if (modify_date == old_modify_date) {
			continue;
		} else {
			g_file_modify_dates[console][entry] = modify_date;
		}
*/
		// Get the game info
		string[string] info;

		switch (console) {
			case "dreamcast":
				try {
					auto game_data = identify_dreamcast_games.GetDreamcastGameInfo(entry);
					foreach (key, value ; game_data) {
						info[key] = value;
					}
					info["file"] = entry;
				} catch (Throwable err) {

				}
				break;
			case "playstation2":
				// FIXME:
				break;
			case "gamecube":
				try {
					auto game_data = getGameCubeGameInfo(entry);
					foreach (key, value ; game_data) {
						info[key] = value;
					}
					info["file"] = entry;
				} catch (Throwable err) {

				}
				break;
			default:
				throw new Exception("Unexpected console: %s".format(console));
		}

		stdout.writefln("!!! info:%s", info); stdout.flush();
		// Save the info in the db
		if (info.length > 0) {
			string title = info["title"];
			string clean_title = SanitizeFileName(title);

			g_db[console][title] = [
				"path" : "%s/%s/".format(path_prefix, clean_title).CleanPath(),
				"binary" : absolutePath(info["file"]),
				"bios" : "",
				"image_big" : "",
				"image_small" : "",
				"developer" : "",
				"publisher" : "",
				"genre" : ""
			];

			if (("developer" in info) != null) {
				g_db[console][title]["developer"] = info["developer"];
			}

			if (("publisher" in info) != null) {
				g_db[console][title]["publisher"] = info["publisher"];
			}

			if (("genre" in info) != null) {
				g_db[console][title]["genre"] = info["genre"];
			}

			// Get the images
			string image_dir = "%s/%s/".format(path_prefix, title);
			const string[] expected_images = ["big", "small"];
			foreach (img ; expected_images) {
				if (exists(image_dir)) {
					string image_name = "image_%s".format(img);
					string image_file = "%s%s.png".format(image_dir, image_name);
					if (exists(image_file)) {
						g_db[console][title][image_name] = image_file;
					}
				}
			}
		}
	}

	// Send the updated game db back to the main thread
	ubyte[] compressed_db = (cast(ubyte[]) g_db.toJSONString()).ToCompressed(CompressionType.Zlib);
	compressed_db = cast(ubyte[]) Base64.encode(compressed_db);

	JSONValue response_json;
	response_json["action"] = "set_db";
	response_json["value"] = compressed_db;
	string response = EncodeMessage(response_json);
	sock.send(response);

	//// Write the db cache file
	//f, err := os.Create(fmt.Sprintf("cache/game_db_%s.json", console))
	//defer f.Close()
	//if (err != null) {
	//	fmt.Printf("Failed to open cache file: %s\r\n", err)
	//	return err
	//}
	//jsoned_data, err := json.MarshalIndent(db[console], "", "\t")
	//if (err != null) {
	//	fmt.Printf("Failed to convert db to json: %s\r\n", err)
	//	return err
	//}
	//f.Write(jsoned_data)

	// Write the modify dates cache file
	//auto f = File("cache/file_modify_dates_%s.json".format(console), "w");
	//scope (exit) f.close();
/*
	if (err != null) {
		fmt.Printf("Failed to open file modify dates file: %s\r\n", err);
		return err;
	}

	string jsoned_data = json.MarshalIndent(g_file_modify_dates[console], "", "\t");
	if (err != null) {
		fmt.Printf("Failed to convert file_modify_dates to json: %s\r\n", err);
		return err;
	}
	f.Write(jsoned_data);

	fmt.Printf("Done getting games from directory.");

	a_task.percentage = 100.0f;
	// FIXME: channel_task_progress <- a_task;

	// Signal that we are done
	// FIXME: channel_is_done <- true;
*/
}
