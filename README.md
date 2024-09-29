# GitHub Repository Manager

A command-line tool for managing GitHub repositories for toggling between private and public, archiving and unarchiving, and displaying detailed repository information.

## Prerequisites

- GitHub CLI (gh)
- dialog
- jq

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/walkertraylor/github-repo-manager.git
   cd github-repo-manager
   ```

2. Ensure you have the required dependencies installed.

3. Make the script executable:
   ```bash
   chmod +x github_repo_manager.sh
   ```

## Usage

Run the script:
```bash
./github_repo_manager.sh
```

Follow the on-screen prompts to manage your GitHub repositories.

## Features

- List all repositories
- Toggle repository visibility
- Save and load repository status
- Search repositories
- View detailed repository information

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

As this project is primarily developed for personal use, contributions may be limited. However, if you have suggestions or improvements, feel free to open an issue or submit a pull request.

## Disclaimer

This tool is designed for use on macOS and may not function correctly on other operating systems. Use at your own risk.
