import os
import re

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
HTML_FILE = os.path.join(BASE_DIR, "index.html")
SELF_FILENAME = os.path.basename(__file__)

def scan_script_files():
    return sorted([
        f for f in os.listdir(BASE_DIR)
        if os.path.isfile(os.path.join(BASE_DIR, f))
        and f != SELF_FILENAME
        and f != "index.html"
    ])

def extract_existing_links(lines):
    inside_ol = False
    preserved_lines = []
    existing_files = set()
    removed_count = 0

    for line in lines:
        if "<ol>" in line:
            inside_ol = True
            preserved_lines.append(line)
            continue
        if "</ol>" in line:
            inside_ol = False
            preserved_lines.append(line)
            continue

        if inside_ol:
            match = re.search(r'href="([^"]+)"', line)
            if match:
                file = match.group(1)
                if os.path.exists(os.path.join(BASE_DIR, file)):
                    preserved_lines.append(line.rstrip())
                    existing_files.add(file)
                else:
                    removed_count += 1
            else:
                preserved_lines.append(line.rstrip())  # Keep malformed or other lines intact
        else:
            preserved_lines.append(line.rstrip())

    return preserved_lines, existing_files, removed_count

def generate_new_li(file):
    name, ext = os.path.splitext(file)
    if ext == ".sh":
        desc = f"{name.replace('_', ' ').title()} (Bash)"
    elif ext == ".py":
        desc = f"{name.replace('_', ' ').title()} (Python)"
    else:
        desc = f"{name.replace('_', ' ').title()} (Unknown)"
    return f'                <li><a download="" href="{file}">{desc}</a></li>'

def update_html():
    with open(HTML_FILE, "r", encoding="utf-8") as f:
        lines = f.readlines()

    updated_lines, existing_files, removed_count = extract_existing_links(lines)

    # Check for extra empty line after </ol> and remove it
    if updated_lines[-1] == "":
        updated_lines.pop()

    ol_start = next(i for i, l in enumerate(updated_lines) if "<ol>" in l)
    ol_end = next(i for i, l in enumerate(updated_lines) if "</ol>" in l)

    script_files = set(scan_script_files())
    new_files = script_files - existing_files

    new_entries = [generate_new_li(f) for f in sorted(new_files)]

    # Create the final updated lines, adding the new entries inside the <ol> block
    new_lines = (
        updated_lines[:ol_end] +  # Everything before </ol>
        new_entries +             # New links added
        updated_lines[ol_end:]    # Everything after </ol>
    )

    # Rewrite the HTML file
    with open(HTML_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(new_lines) + "\n")

    print(f"✅ index.html updated.")
    print(f"➕ {len(new_entries)} link(s) added.")
    print(f"➖ {removed_count} link(s) removed.")

if __name__ == "__main__":
    update_html()
