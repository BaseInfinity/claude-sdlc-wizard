'use strict';

const fs = require('fs');
const path = require('path');

const RESET = '\x1b[0m';
const GREEN = '\x1b[32m';
const YELLOW = '\x1b[33m';
const CYAN = '\x1b[36m';

const TEMPLATES_DIR = path.join(__dirname, 'templates');
const WIZARD_DOC = path.join(__dirname, '..', 'CLAUDE_CODE_SDLC_WIZARD.md');

const FILES = [
  { src: 'settings.json', dest: '.claude/settings.json' },
  { src: 'hooks/sdlc-prompt-check.sh', dest: '.claude/hooks/sdlc-prompt-check.sh', executable: true },
  { src: 'hooks/tdd-pretool-check.sh', dest: '.claude/hooks/tdd-pretool-check.sh', executable: true },
  { src: 'hooks/instructions-loaded-check.sh', dest: '.claude/hooks/instructions-loaded-check.sh', executable: true },
  { src: 'skills/sdlc/SKILL.md', dest: '.claude/skills/sdlc/SKILL.md' },
  { src: 'skills/testing/SKILL.md', dest: '.claude/skills/testing/SKILL.md' },
];

const GITIGNORE_ENTRIES = ['.claude/plans/', '.claude/settings.local.json'];

function planOperations(targetDir, { force }) {
  const ops = [];

  for (const file of FILES) {
    const destPath = path.join(targetDir, file.dest);
    const exists = fs.existsSync(destPath);
    ops.push({
      src: path.join(TEMPLATES_DIR, file.src),
      dest: destPath,
      relativeDest: file.dest,
      action: exists ? (force ? 'OVERWRITE' : 'SKIP') : 'CREATE',
      executable: file.executable || false,
    });
  }

  // Wizard doc
  const wizardDest = path.join(targetDir, 'CLAUDE_CODE_SDLC_WIZARD.md');
  const wizardExists = fs.existsSync(wizardDest);
  ops.push({
    src: WIZARD_DOC,
    dest: wizardDest,
    relativeDest: 'CLAUDE_CODE_SDLC_WIZARD.md',
    action: wizardExists ? (force ? 'OVERWRITE' : 'SKIP') : 'CREATE',
    executable: false,
  });

  return ops;
}

function ensureDir(filePath) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
}

function executeOperations(ops) {
  for (const op of ops) {
    if (op.action === 'SKIP') continue;
    ensureDir(op.dest);
    fs.copyFileSync(op.src, op.dest);
    if (op.executable) {
      fs.chmodSync(op.dest, 0o755);
    }
  }
}

function updateGitignore(targetDir, { dryRun }) {
  const gitignorePath = path.join(targetDir, '.gitignore');
  let content = '';
  if (fs.existsSync(gitignorePath)) {
    content = fs.readFileSync(gitignorePath, 'utf8');
  }

  const toAdd = GITIGNORE_ENTRIES.filter((entry) => !content.includes(entry));
  if (toAdd.length === 0) return [];

  if (!dryRun) {
    const suffix = (content && !content.endsWith('\n') ? '\n' : '') + toAdd.join('\n') + '\n';
    fs.appendFileSync(gitignorePath, suffix);
  }

  return toAdd;
}

function printOps(ops) {
  for (const op of ops) {
    const color = op.action === 'CREATE' ? GREEN : op.action === 'SKIP' ? YELLOW : CYAN;
    console.log(`  ${color}${op.action}${RESET}  ${op.relativeDest}`);
  }
}

function init(targetDir, { force = false, dryRun = false } = {}) {
  const ops = planOperations(targetDir, { force });

  if (dryRun) {
    console.log('Dry run — no files will be written:\n');
    printOps(ops);
    const gitignoreAdds = updateGitignore(targetDir, { dryRun: true });
    if (gitignoreAdds.length > 0) {
      console.log(`  ${GREEN}APPEND${RESET}  .gitignore (${gitignoreAdds.join(', ')})`);
    }
    return true;
  }

  console.log('');
  printOps(ops);

  if (ops.every((o) => o.action === 'SKIP')) {
    console.log('\nAll files already exist. Use --force to overwrite.');
    return true;
  }

  executeOperations(ops);

  const gitignoreAdds = updateGitignore(targetDir, { dryRun: false });
  if (gitignoreAdds.length > 0) {
    console.log(`  ${GREEN}APPEND${RESET}  .gitignore (${gitignoreAdds.join(', ')})`);
  }

  console.log(`
${GREEN}SDLC Wizard installed successfully!${RESET}

Next steps:
  1. Start Claude Code in this directory
  2. Tell Claude: "Run the SDLC wizard setup"
  3. Claude will scan your project and create CLAUDE.md, SDLC.md, TESTING.md, ARCHITECTURE.md

The wizard doc is at: CLAUDE_CODE_SDLC_WIZARD.md
  `);

  return true;
}

module.exports = { init, planOperations, GITIGNORE_ENTRIES };
