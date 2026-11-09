package main

import (
	"errors"
	"fmt"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

const defaultDest = "~/Code/Github.com"

func main() {
	args := os.Args[1:]
	gitPath, err := exec.LookPath("git")
	if err != nil {
		fail(fmt.Errorf("git executable not found: %w", err))
	}
	args, err = rewriteClone(args)
	if err != nil {
		fail(err)
	}
	if err := executeGit(gitPath, args); err != nil {
		fail(err)
	}
}

func rewriteClone(args []string) ([]string, error) {
	if len(args) == 1 {
		if _, _, ok := githubRepo(args[0]); ok {
			args = append([]string{"clone"}, args...)
		}
	}
	if len(args) < 2 || args[0] != "clone" {
		return args, nil
	}
	owner, repo, ok := githubRepo(args[len(args)-1])
	if !ok {
		return args, nil
	}

	base := os.Getenv("GITSO_DEST")
	if base == "" {
		base = defaultDest
	}
	base = expandHome(base)
	dest := filepath.Join(base, owner, repo)
	if err := os.MkdirAll(filepath.Dir(dest), 0o755); err != nil {
		return nil, fmt.Errorf("create destination: %w", err)
	}
	return append(args, dest), nil
}

func githubRepo(raw string) (string, string, bool) {
	var path string
	if strings.HasPrefix(strings.ToLower(raw), "git@github.com:") {
		path = raw[len("git@github.com:"):]
	} else {
		u, err := url.Parse(raw)
		if err != nil || !strings.EqualFold(u.Hostname(), "github.com") || u.RawQuery != "" || u.Fragment != "" {
			return "", "", false
		}
		switch u.Scheme {
		case "http", "https", "ssh", "git":
		default:
			return "", "", false
		}
		path = u.Path
	}

	parts := strings.Split(strings.Trim(path, "/"), "/")
	if len(parts) != 2 {
		return "", "", false
	}
	owner, repo := parts[0], strings.TrimSuffix(parts[1], ".git")
	if !validName(owner) || !validName(repo) {
		return "", "", false
	}
	return owner, repo, true
}

func validName(s string) bool {
	if s == "" || s == "." || s == ".." {
		return false
	}
	for _, r := range s {
		if r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r >= '0' && r <= '9' || strings.ContainsRune("-_.", r) {
			continue
		}
		return false
	}
	return true
}

func expandHome(path string) string {
	if path != "~" && !strings.HasPrefix(path, "~/") {
		return path
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return path
	}
	if path == "~" {
		return home
	}
	return filepath.Join(home, strings.TrimPrefix(path, "~/"))
}

func fail(err error) {
	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) {
		os.Exit(exitErr.ExitCode())
	}
	fmt.Fprintln(os.Stderr, "gitso:", err)
	os.Exit(1)
}
