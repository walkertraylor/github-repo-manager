# GitHub Repository Manager

A command-line tool for managing GitHub repositories, including visibility toggling and detailed repository information.

## Development Environment

This project is developed and tested on macOS using Zsh. It is not optimized for other operating systems or shells.

- **Operating System**: macOS
- **Shell**: Zsh

To check your Zsh version, run:
```zsh
zsh --version
```

## Prerequisites

- GitHub CLI (gh)
- dialog
- jq

## Installation

1. Clone the repository:
   ```zsh
   git clone https://github.com/yourusername/github-repo-manager.git
   cd github-repo-manager
   ```

2. Ensure you have the required dependencies:
   ```zsh
   brew install gh dialog jq
   ```

3. Make the script executable:
   ```zsh
   chmod +x github_repo_manager.sh
   ```

## Usage

Run the script:
```zsh
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

As this project is primarily developed for personal use on macOS with Zsh, contributions may be limited. However, if you have suggestions or improvements, feel free to open an issue or submit a pull request.

## Disclaimer

This tool is designed for use on macOS with Zsh and may not function correctly on other operating systems or shells. Use at your own risk.
