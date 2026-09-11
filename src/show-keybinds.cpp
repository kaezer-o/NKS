#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <regex>
#include <sstream>
#include <string>

std::string trim(const std::string& str) {
    const size_t first = str.find_first_not_of(" \t");
    if (first == std::string::npos) return "";
    const size_t last = str.find_last_not_of(" \t");
    return str.substr(first, last - first + 1);
}

void replace_all(std::string& str, const std::string& from, const std::string& to) {
    if (from.empty()) return;
    size_t pos = 0;
    while ((pos = str.find(from, pos)) != std::string::npos) {
        str.replace(pos, from.size(), to);
        pos += to.size();
    }
}

std::string parse_lua_binds(const std::string& filepath) {
    std::ifstream file(filepath);
    if (!file.is_open()) return "";

    std::ostringstream output;
    output << " ────────────────── KEYBINDINGS ────────────────── \n";

    const std::regex key_regex(
        R"REGEX(^\s*bind\s*\(\s*(?:M\s*\.\.\s*)?"([^"]*)")REGEX");
    const std::regex quoted_regex(R"REGEX("([^"]*)")REGEX");

    std::string line;
    bool found = false;
    while (std::getline(file, line)) {
        if (!std::regex_search(line, key_regex)) continue;

        std::string display_key;
        if (line.find("M .. \" + \" .. key") != std::string::npos) {
            display_key = "SUPER + 1..0";
        } else if (line.find("M .. \" + SHIFT + \" .. key") != std::string::npos) {
            display_key = "SUPER + SHIFT + 1..0";
        } else {
            std::smatch key_match;
            if (!std::regex_search(line, key_match, key_regex)) continue;
            display_key = key_match[1].str();
            if (line.find("M ..") != std::string::npos && display_key.rfind(" + ", 0) == 0) {
                display_key = "SUPER" + display_key;
            }
            replace_all(display_key, "M + ", "SUPER + ");
        }

        std::string description;
        for (std::sregex_iterator it(line.begin(), line.end(), quoted_regex), end_it; it != end_it; ++it) {
            description = (*it)[1].str();
        }
        if (description.empty()) continue;

        output << "[" << std::left << std::setw(34) << display_key << "] "
                << description << "\n";
        found = true;
    }

    return found ? output.str() : "";
}

int main() {
    const char* xdg_env = std::getenv("XDG_CONFIG_HOME");
    const char* home_env = std::getenv("HOME");
    if (!home_env || *home_env == '\0') {
        std::cerr << "Error: HOME is not set.\n";
        return 1;
    }

    const std::string config_home =
        (xdg_env && *xdg_env) ? std::string(xdg_env) : std::string(home_env) + "/.config";
    const std::string lua_config = config_home + "/hypr/hyprland.lua";
    const std::string full_output = parse_lua_binds(lua_config);

    if (full_output.empty()) {
        std::cerr << "No Lua keybinds found: " << lua_config << "\n";
        return 1;
    }

    const std::string rofi_cmd =
        R"(rofi -dmenu -i -p "  Search Keybinds" -theme-str 'window { width: 1000px; border-radius: 12px; } listview { lines: 20; fixed-height: true; } element-text { font: "monospace 11"; }')";

    FILE* pipe = popen(rofi_cmd.c_str(), "w");
    if (!pipe) {
        std::cerr << "Failed to open pipe to Rofi.\n";
        return 1;
    }

    std::fwrite(full_output.c_str(), 1, full_output.size(), pipe);
    pclose(pipe);
    return 0;
}
