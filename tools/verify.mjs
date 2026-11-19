// ROT ORBIT's local pre-commit check. No dependencies and no Roblox credentials.
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const scratch = join(root, 'out', 'verify');

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { cwd: root, encoding: 'utf8', ...options });
  if (result.error || result.status !== 0) {
    process.stderr.write(result.stdout ?? '');
    process.stderr.write(result.stderr ?? '');
    throw result.error ?? new Error(`${command} exited ${result.status}`);
  }
  return result.stdout;
}

function scriptsIn(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    if (entry.name.startsWith('.')) throw new Error(`Hidden file under src: ${entry.name}`);
    const path = join(directory, entry.name);
    if (entry.isDirectory()) return scriptsIn(path);
    if (!entry.isFile()) throw new Error(`Not a plain file: ${path}`);
    return entry.name.endsWith('.luau') ? [relative(root, path)] : [];
  });
}

process.stdout.write(run('rojo', ['build', 'default.project.json', '--output', 'game.rbxl']));
const scripts = scriptsIn(join(root, 'src'));
run('luau-compile', ['--null', ...scripts]);
rmSync(scratch, { recursive: true, force: true });
mkdirSync(scratch, { recursive: true });
run(process.execPath, ['main.ts'], { env: { ...process.env, MAKEFUN_OUTPUT_DIR: scratch } });
for (const artifact of ['game.rbxl', 'src', 'screenshots', 'PLAY.json', 'dossier.json']) {
  if (!existsSync(join(scratch, artifact))) throw new Error(`Missing output artifact: ${artifact}`);
}
JSON.parse(readFileSync(join(scratch, 'dossier.json'), 'utf8'));
process.stdout.write(`Verified ${scripts.length} Luau scripts; place ${statSync(join(root, 'game.rbxl')).size} bytes; dossier written to out/verify/.\n`);
