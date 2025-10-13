# Git Guide for Coolify Admin

## Repository Status

✅ Git initialized and configured  
✅ `.gitignore` protecting sensitive files  
✅ `.gitattributes` normalizing line endings  
✅ Initial commit completed (110 files)

## Common Git Commands

### Check Status
```bash
# See what's changed
git status

# See what's ignored
git status --ignored
```

### Making Changes
```bash
# Add specific files
git add app/controllers/my_controller.rb

# Add all changes
git add -A

# Commit with message
git commit -m "Add new feature"
```

### Viewing History
```bash
# See commit log
git log --oneline

# See detailed log
git log --stat

# See changes in a file
git log -p app/controllers/welcome_controller.rb
```

### Branches
```bash
# Create new branch
git checkout -b feature/my-feature

# Switch branches
git checkout master

# List branches
git branch -a

# Delete branch
git branch -d feature/my-feature
```

### Remote Repository (when you add one)
```bash
# Add remote (GitHub, GitLab, etc.)
git remote add origin https://github.com/yourusername/coolify-admin.git

# Push to remote
git push -u origin master

# Pull from remote
git pull origin master
```

## What's Protected (Never Committed)

🔒 **Security Files:**
- `config/master.key` - Rails encryption key
- `.env` files - Environment variables
- `.kamal/secrets` - Deployment credentials

🗄️ **Data Files:**
- `*.sqlite3` - SQLite databases
- `log/*.log` - Application logs
- `tmp/*` - Temporary files
- `storage/*` - Uploaded files

🔧 **Build Files:**
- `node_modules/` - Node dependencies
- `/public/assets` - Compiled assets
- `tmp/cache/` - Application cache

💻 **IDE Files:**
- `.vscode/` - VS Code settings
- `.idea/` - RubyMine/IntelliJ
- `*.swp` - Vim swap files
- `.DS_Store` - Mac OS files

## Quick Tips

### Undo Staged Changes
```bash
git reset HEAD <file>
```

### Undo Last Commit (keep changes)
```bash
git reset --soft HEAD~1
```

### See What Will Be Committed
```bash
git diff --staged
```

### Temporarily Save Changes
```bash
git stash
git stash pop
```

### Check If File Is Ignored
```bash
git check-ignore -v <filename>
```

## Best Practices

✅ **DO:**
- Commit early and often
- Write meaningful commit messages
- Keep commits focused (one feature/fix per commit)
- Review changes before committing (`git diff`)
- Use branches for features

❌ **DON'T:**
- Commit sensitive data (keys, passwords)
- Commit large binary files
- Commit dependencies (node_modules, vendor)
- Force push to shared branches
- Commit commented-out code

## Example Workflow

```bash
# 1. Check status
git status

# 2. Create feature branch
git checkout -b feature/add-user-auth

# 3. Make changes to files
# ... edit code ...

# 4. Review changes
git diff

# 5. Stage changes
git add app/controllers/auth_controller.rb
git add app/models/user.rb

# 6. Commit
git commit -m "Add user authentication system"

# 7. Switch back to main branch
git checkout master

# 8. Merge feature
git merge feature/add-user-auth

# 9. Delete feature branch
git branch -d feature/add-user-auth
```

## Need Help?

```bash
# Git help
git help <command>

# Show ignored files
git status --ignored

# Check what will be committed
git status --short
```

---

**Remember:** Your Rails encryption keys and secrets are safe - they're ignored by Git! 🔒
