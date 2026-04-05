const { execSync } = require('child_process');
const assert = require('assert');

// Integration: full CLI invocation
const help = execSync('node bin/mycli.js --help').toString();
assert(help.includes('Usage:'), 'Help should show usage');

// Behavior: exit code on missing args
try {
    execSync('node bin/mycli.js', { stdio: 'pipe' });
    assert.fail('Should exit non-zero with no args');
} catch (e) {
    assert.strictEqual(e.status, 1);
}

console.log('All CLI tests passed');
