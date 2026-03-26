import Foundation

/// Maps tool/command names to cute Clawy messages.
struct ThoughtBubble {

    /// Get the cute message for a given tool and command.
    /// Returns nil for unrecognized commands (no bubble shown).
    static func message(toolName: String?, command: String?) -> String? {
        // For Bash tool, use the actual CLI command
        if toolName == "Bash", let cmd = command, !cmd.isEmpty {
            return bashMessage(for: cmd)
        }

        return nil
    }

    private static func bashMessage(for command: String) -> String? {
        // Strip path prefixes (e.g. /usr/bin/rm -> rm, ./scripts/foo.sh -> foo.sh)
        let cmd = command.split(separator: "/").last.map(String.init) ?? command

        // Match by file extension for scripts
        if cmd.hasSuffix(".sh") || cmd.hasSuffix(".bash") || cmd.hasSuffix(".zsh") { return "Bashy bashy?" }
        if cmd.hasSuffix(".py") { return "Snakey snakey?" }
        if cmd.hasSuffix(".js") || cmd.hasSuffix(".ts") || cmd.hasSuffix(".mjs") { return "Nodey nodey?" }
        if cmd.hasSuffix(".rb") { return "Ruby ruby?" }
        if cmd.hasSuffix(".pl") { return "Perly perly?" }
        if cmd.hasSuffix(".swift") { return "Swifty swifty?" }

        switch cmd {
        case "rm":       return "Trashy trashy?"
        case "rmdir":    return "Trashy trashy?"
        case "git":      return "Gitty gitty?"
        case "npm":      return "Packy packy?"
        case "npx":      return "Packy packy?"
        case "yarn":     return "Yarny yarny?"
        case "pnpm":     return "Packy packy?"
        case "bun":      return "Bunny bunny?"
        case "bunx":     return "Bunny bunny?"
        case "pip":      return "Pippy pippy?"
        case "pip3":     return "Pippy pippy?"
        case "python":   return "Snakey snakey?"
        case "python3":  return "Snakey snakey?"
        case "node":     return "Nodey nodey?"
        case "deno":     return "Dinoy dinoy?"
        case "curl":     return "Fetchy fetchy?"
        case "wget":     return "Fetchy fetchy?"
        case "docker":   return "Docky docky?"
        case "mkdir":    return "Makey makey?"
        case "chmod":    return "Changy changy?"
        case "chown":    return "Changy changy?"
        case "mv":       return "Movey movey?"
        case "cp":       return "Copey copey?"
        case "sed":      return "Replacy replacy?"
        case "awk":      return "Replacy replacy?"
        case "kill":     return "Killy killy?"
        case "killall":  return "Killy killy?"
        case "bash":     return "Bashy bashy?"
        case "sh":       return "Bashy bashy?"
        case "zsh":      return "Bashy bashy?"
        case "grep":     return "Greppy greppy?"
        case "rg":       return "Rippy greppy?"
        case "cat":      return "Meowy meowy?"
        case "ps":       return "Pssst pssst?"
        case "sudo":     return "Bossy bossy?"
        case "aws":      return "Awwsy cloudy?"
        case "gcloud":   return "Googly cloudy?"
        case "az":       return "Zury Azury?"
        case "bq":       return "Query query?"
        case "tar":      return "Squishy squashy?"
        case "zip":      return "Squishy squashy?"
        case "unzip":    return "Unsquishy squishy?"
        case "gzip":     return "Squishy squashy?"
        case "gunzip":   return "Unsquishy squishy?"
        case "touch":    return "Touchy touchy?"
        case "brew":     return "Brewy brewy?"
        case "swift":    return "Swifty swifty?"
        case "cargo":    return "Cargoy cargoy?"
        case "go":       return "Gopher gopher?"
        case "make":     return "Makey makey?"
        case "cmake":    return "Makey makey?"
        case "ssh":      return "Shushy shushy?"
        case "kubectl":  return "Kubey kubey?"
        case "top":      return "Tippy toppy?"
        case "htop":     return "Tippy toppy?"
        case "nginx":    return "Proxy proxy?"
        case "tmux":     return "Tuxy muxy?"
        case "gh":       return "Gitty hubby?"
        case "terraform": return "Formy formy?"
        case "redis-cli": return "Reddy weddy?"
        case "mongo":    return "Mongo bongo?"
        case "mongosh":  return "Mongo bongo?"
        case "psql":     return "Posty squealy?"
        case "mysql":    return "My squealy?"
        case "sqlite3":  return "Squealy litey?"
        default:         return nil
        }
    }
}
