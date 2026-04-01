'use strict';

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const RESET = '\x1b[0m';
const RED = '\x1b[31m';
const GREEN = '\x1b[32m';
const YELLOW = '\x1b[33m';
const MAGENTA = '\x1b[35m';
const CYAN = '\x1b[36m';

const TEMPLATES_DIR = path.join(__dirname, 'templates');
const WIZARD_DOC = path.join(__dirname, '..', 'CLAUDE_CODE_SDLC_WIZARD.md');

const FILES = [
  { src: 'settings.json', dest: '.claude/settings.json' },
  { src: 'hooks/sdlc-prompt-check.sh', dest: '.claude/hooks/sdlc-prompt-check.sh', executable: true },
  { src: 'hooks/tdd-pretool-check.sh', dest: '.claude/hooks/tdd-pretool-check.sh', executable: true },
  { src: 'hooks/instructions-loaded-check.sh', dest: '.claude/hooks/instructions-loaded-check.sh', executable: true },
  { src: 'skills/sdlc/SKILL.md', dest: '.claude/skills/sdlc/SKILL.md' },
  { src: 'skills/setup/SKILL.md', dest: '.claude/skills/setup/SKILL.md' },
  { src: 'skills/update/SKILL.md', dest: '.claude/skills/update/SKILL.md' },
];

const WIZARD_HOOK_MARKERS = FILES
  .filter((f) => f.executable && f.dest.startsWith('.claude/hooks/'))
  .map((f) => path.basename(f.src));

const GITIGNORE_ENTRIES = ['.claude/plans/', '.claude/settings.local.json'];

// Paths from previous versions that should be removed on upgrade
const OBSOLETE_PATHS = [
  '.claude/skills/testing',  // consolidated into /sdlc in v1.17.0
];

function isWizardHookEntry(hookEntry) {
  if (!hookEntry || !hookEntry.hooks) return false;
  return hookEntry.hooks.some((h) =>
    WIZARD_HOOK_MARKERS.some((marker) => h.command && h.command.includes(marker))
  );
}

function mergeSettings(existingPath, templatePath, force) {
  try {
    const existing = JSON.parse(fs.readFileSync(existingPath, 'utf8'));
    const template = JSON.parse(fs.readFileSync(templatePath, 'utf8'));

    if (!existing.hooks) existing.hooks = {};

    for (const [event, templateEntries] of Object.entries(template.hooks || {})) {
      if (!existing.hooks[event]) {
        existing.hooks[event] = templateEntries;
        continue;
      }

      // Each template event has exactly one hook entry
      const templateEntry = templateEntries[0];
      const existingIdx = existing.hooks[event].findIndex(isWizardHookEntry);

      if (existingIdx === -1) {
        existing.hooks[event].push(templateEntry);
      } else if (force) {
        existing.hooks[event][existingIdx] = templateEntry;
      }
    }

    const merged = JSON.stringify(existing, null, 2) + '\n';
    const original = fs.readFileSync(existingPath, 'utf8');
    return merged === original ? null : merged;
  } catch (_) {
    return null;
  }
}

function planOperations(targetDir, { force }) {
  const ops = [];

  for (const file of FILES) {
    const destPath = path.join(targetDir, file.dest);
    const srcPath = path.join(TEMPLATES_DIR, file.src);
    const exists = fs.existsSync(destPath);

    if (exists && file.dest === '.claude/settings.json') {
      const merged = mergeSettings(destPath, srcPath, force);
      if (merged) {
        ops.push({
          src: srcPath,
          dest: destPath,
          relativeDest: file.dest,
          action: 'MERGE',
          mergedContent: merged,
          executable: false,
        });
        continue;
      }
      // Invalid JSON — fall through to normal SKIP/OVERWRITE
    }

    ops.push({
      src: srcPath,
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
    if (op.action === 'MERGE') {
      fs.writeFileSync(op.dest, op.mergedContent);
    } else {
      fs.copyFileSync(op.src, op.dest);
    }
    if (op.executable) {
      fs.chmodSync(op.dest, 0o755);
    }
  }
}

function removeObsoletePaths(targetDir, { dryRun }) {
  const removed = [];
  for (const rel of OBSOLETE_PATHS) {
    const fullPath = path.join(targetDir, rel);
    if (fs.existsSync(fullPath)) {
      if (!dryRun) {
        fs.rmSync(fullPath, { recursive: true, force: true });
      }
      removed.push(rel);
    }
  }
  return removed;
}

function updateGitignore(targetDir, { dryRun }) {
  const gitignorePath = path.join(targetDir, '.gitignore');
  let content = '';
  if (fs.existsSync(gitignorePath)) {
    content = fs.readFileSync(gitignorePath, 'utf8');
  }

  const lines = content.split('\n').map((l) => l.trim()).filter((l) => l && !l.startsWith('#'));
  const toAdd = GITIGNORE_ENTRIES.filter((entry) => !lines.includes(entry));
  if (toAdd.length === 0) return [];

  if (!dryRun) {
    const suffix = (content && !content.endsWith('\n') ? '\n' : '') + toAdd.join('\n') + '\n';
    fs.appendFileSync(gitignorePath, suffix);
  }

  return toAdd;
}

function printOps(ops) {
  for (const op of ops) {
    const color = op.action === 'CREATE' ? GREEN
      : op.action === 'SKIP' ? YELLOW
      : op.action === 'MERGE' ? MAGENTA
      : CYAN;
    console.log(`  ${color}${op.action}${RESET}  ${op.relativeDest}`);
  }
}

function init(targetDir, { force = false, dryRun = false } = {}) {
  const ops = planOperations(targetDir, { force });

  if (dryRun) {
    console.log('Dry run — no files will be written:\n');
    printOps(ops);
    const obsolete = removeObsoletePaths(targetDir, { dryRun: true });
    for (const p of obsolete) {
      console.log(`  ${RED}REMOVE${RESET}  ${p} (obsolete)`);
    }
    const gitignoreAdds = updateGitignore(targetDir, { dryRun: true });
    if (gitignoreAdds.length > 0) {
      console.log(`  ${GREEN}APPEND${RESET}  .gitignore (${gitignoreAdds.join(', ')})`);
    }
    return true;
  }

  console.log('');
  printOps(ops);

  // Always clean up obsolete paths, even when all managed files are SKIP
  const obsolete = removeObsoletePaths(targetDir, { dryRun: false });
  for (const p of obsolete) {
    console.log(`  ${RED}REMOVE${RESET}  ${p} (obsolete)`);
  }

  if (ops.every((o) => o.action === 'SKIP') && obsolete.length === 0) {
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

${YELLOW}Restart Claude Code${RESET} to load new hooks and skills:
  ${CYAN}/exit${RESET} then ${CYAN}claude --continue${RESET}  (keeps conversation history)
  ${CYAN}/exit${RESET} then ${CYAN}claude${RESET}              (fresh start)

Next steps:
  1. Restart Claude Code (see above)
  2. Tell Claude anything — setup auto-invokes when SDLC files are missing
  3. Claude reads the wizard doc and creates CLAUDE.md, SDLC.md, TESTING.md, ARCHITECTURE.md

The wizard doc is at: CLAUDE_CODE_SDLC_WIZARD.md
  `);

  return true;
}

function check(targetDir, { json = false } = {}) {
  const results = [];

  for (const file of FILES) {
    const destPath = path.join(targetDir, file.dest);
    const srcPath = path.join(TEMPLATES_DIR, file.src);
    results.push(checkFile(srcPath, destPath, file.dest, file.executable || false));
  }

  const wizardDest = path.join(targetDir, 'CLAUDE_CODE_SDLC_WIZARD.md');
  results.push(checkFile(WIZARD_DOC, wizardDest, 'CLAUDE_CODE_SDLC_WIZARD.md', false));

  const gitignorePath = path.join(targetDir, '.gitignore');
  results.push(checkGitignore(gitignorePath));

  let updateInfo = null;
  try {
    const { execSync } = require('child_process');
    const latest = execSync('npm view agentic-sdlc-wizard version 2>/dev/null', {
      encoding: 'utf8',
      timeout: 5000,
    }).trim();
    const current = require('../package.json').version;
    if (latest !== current) {
      updateInfo = { current, latest };
    }
  } catch (_) {
    // Offline or npm unavailable — skip update check
  }

  const hasDrift = results.some((r) => r.status === 'MISSING' || r.status === 'DRIFT');

  if (json) {
    console.log(JSON.stringify({ files: results, update: updateInfo }, null, 2));
  } else {
    for (const r of results) {
      const color = r.status === 'MATCH' ? GREEN : r.status === 'MISSING' ? RED : YELLOW;
      console.log(`  ${color}${r.status}${RESET}  ${r.file}`);
      if (r.details) console.log(`         ${r.details}`);
    }
    if (updateInfo) {
      console.log(`\n  ${YELLOW}UPDATE${RESET}  v${updateInfo.current} -> v${updateInfo.latest}`);
      console.log('         Run: npx agentic-sdlc-wizard init --force');
    }
  }

  return { results, updateInfo, hasDrift };
}

function checkFile(srcPath, destPath, relativeDest, shouldBeExecutable) {
  if (!fs.existsSync(destPath)) {
    return { file: relativeDest, status: 'MISSING' };
  }
  const srcHash = crypto.createHash('sha256').update(fs.readFileSync(srcPath)).digest('hex');
  const destHash = crypto.createHash('sha256').update(fs.readFileSync(destPath)).digest('hex');
  const result = {
    file: relativeDest,
    status: srcHash === destHash ? 'MATCH' : 'CUSTOMIZED',
  };

  if (shouldBeExecutable) {
    try {
      fs.accessSync(destPath, fs.constants.X_OK);
    } catch (_) {
      result.status = 'DRIFT';
      result.details = 'Missing executable permission (chmod +x)';
    }
  }

  return result;
}

function checkGitignore(gitignorePath) {
  if (!fs.existsSync(gitignorePath)) {
    return { file: '.gitignore', status: 'MISSING', details: 'No .gitignore found' };
  }
  const lines = fs.readFileSync(gitignorePath, 'utf8').split('\n')
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith('#'));
  const missing = GITIGNORE_ENTRIES.filter((e) => !lines.includes(e));
  if (missing.length > 0) {
    return { file: '.gitignore', status: 'DRIFT', details: `Missing entries: ${missing.join(', ')}` };
  }
  return { file: '.gitignore', status: 'MATCH' };
}

module.exports = { init, check, planOperations, GITIGNORE_ENTRIES };
