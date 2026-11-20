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
// These settings require authoring capabilities; a successful compile cannot catch this.
for (const script of scripts) {
  const source = readFileSync(join(root, script), 'utf8');
  if (/(?:Workspace|workspace)\.(?:FallenPartsDestroyHeight|StreamingEnabled|FilteringEnabled)\s*=|Lighting\.Technology\s*=/.test(source)) {
    throw new Error(`Restricted runtime service assignment in ${script}; set it in default.project.json`);
  }
}
// Runtime WorldBuilder atmosphere is exercised with Roblox's positive default density.
const project = JSON.parse(readFileSync(join(root, 'default.project.json'), 'utf8'));
function checkPlaceAtmospheres(node) {
  if (node?.$className === 'Atmosphere' && !(node.$properties?.Density <= 0)) {
    throw new Error('Positive Atmosphere density in default.project.json');
  }
  if (node && typeof node === 'object') Object.values(node).forEach(checkPlaceAtmospheres);
}
checkPlaceAtmospheres(project.tree.Lighting);
for (const script of scripts.filter(path => path !== join('src', 'server', 'WorldBuilder.luau'))) {
  if (/Instance\.new\s*\(\s*["']Atmosphere["']/.test(readFileSync(join(root, script), 'utf8'))) {
    throw new Error(`Atmosphere outside the verified lighting builder in ${script}`);
  }
}
for (const check of ['check-collections.mjs', 'check-combat.mjs', 'check-controls.mjs', 'check-orbit.mjs']) {
  process.stdout.write(run(process.execPath, [join('tools', check)]));
}
rmSync(scratch, { recursive: true, force: true });
mkdirSync(scratch, { recursive: true });
run(process.execPath, ['main.ts'], { env: { ...process.env, MAKEFUN_OUTPUT_DIR: scratch } });
for (const artifact of ['game.rbxl', 'src', 'screenshots', 'PLAY.json', 'dossier.json']) {
  if (!existsSync(join(scratch, artifact))) throw new Error(`Missing output artifact: ${artifact}`);
}
JSON.parse(readFileSync(join(scratch, 'dossier.json'), 'utf8'));
if (process.argv.includes('--submission')) {
  process.stdout.write(run(process.execPath, ['tools/check-captures.mjs']));
}
process.stdout.write(`Verified ${scripts.length} Luau scripts; place ${statSync(join(root, 'game.rbxl')).size} bytes; dossier written to out/verify/.\n`);
