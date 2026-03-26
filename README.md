Welcome to Ollama Model Manager "O.M.M."

-How to Install O.M.M.

Step 1. Download the newest release and extract the zip
"omm.zip" -> "/Downloads/omm"

Step 2. Run the installer script
"open a terminal and type cd Downloads/omm then

# macOS / Linux
chmod +x install.sh
./install.sh

# Windows (Git Bash)
bash install.sh

Step 3. Verify it worked
"now simply run the command ollama-manager"
If the banner appears, you're good to go.

-How to use O.M.M.

Running the command ollama-manager lists both running and installed models in one easy command adding the flags below will help you remove or stop models as you please

Commands

| Flag | What it does |
|------|-------------|
| `-rm` | Remove models by number |
| `-a` | add models by model id or copying ollama run commands ie "ollama run llama3.1" |
| `-s` | Stop running models by number |
| `-purge` | Delete **all** models (double confirmation) |
| `-h` | Help |


-Requirements
- Ollama "https://ollama.com
