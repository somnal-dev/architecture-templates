#!/usr/bin/env tsx
import * as fs from 'fs';
import * as path from 'path';
import * as readline from 'readline';

// ─── Readline ──────────────────────────────────────────────────
const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

function prompt(question: string): Promise<string> {
  return new Promise(resolve => rl.question(question, resolve));
}

// ─── Recursive file utilities ──────────────────────────────────
function findFiles(dir: string, predicate: (filePath: string) => boolean): string[] {
  const results: string[] = [];
  if (!fs.existsSync(dir)) return results;

  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...findFiles(fullPath, predicate));
    } else if (predicate(fullPath)) {
      results.push(fullPath);
    }
  }
  return results;
}

function findDirs(dir: string, predicate: (dirPath: string) => boolean): string[] {
  const results: string[] = [];
  if (!fs.existsSync(dir)) return results;

  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...findDirs(fullPath, predicate));
      if (predicate(fullPath)) results.push(fullPath);
    }
  }
  return results;
}

function replaceInFile(filePath: string, from: string | RegExp, to: string): void {
  let content = fs.readFileSync(filePath, 'utf-8');
  const pattern = typeof from === 'string'
    ? new RegExp(from.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g')
    : from;
  const updated = content.replace(pattern, to);
  if (updated !== content) fs.writeFileSync(filePath, updated);
}

function replaceInFileMulti(filePath: string, replacements: Array<[string | RegExp, string]>): void {
  let content = fs.readFileSync(filePath, 'utf-8');
  for (const [from, to] of replacements) {
    const pattern = typeof from === 'string'
      ? new RegExp(from.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g')
      : from;
    content = content.replace(pattern, to);
  }
  fs.writeFileSync(filePath, content);
}

function copyDirRecursive(src: string, dest: string): void {
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copyDirRecursive(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

function removeEmptyDirs(dir: string): void {
  if (!fs.existsSync(dir)) return;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) removeEmptyDirs(path.join(dir, entry.name));
  }
  try {
    const entries = fs.readdirSync(dir);
    if (entries.length === 0) fs.rmdirSync(dir);
  } catch {
    // ignore
  }
}

function removeRecursive(p: string): void {
  if (!fs.existsSync(p)) return;
  fs.rmSync(p, { recursive: true, force: true });
}

// ─── Main ──────────────────────────────────────────────────────
async function main() {
  const args = process.argv.slice(2);
  const projectRoot = path.resolve(__dirname, '..');
  process.chdir(projectRoot);

  // ─── Gather inputs ─────────────────────────────────────────
  let packageName = args[0] || '';
  let dataModel   = args[1] || '';
  let projectName = args[2] || '';

  if (!packageName) packageName = await prompt('Enter new package name (e.g. com.example.app): ');
  if (!packageName) { console.error('Package name is required. Exiting.'); rl.close(); process.exit(2); }

  if (!dataModel) dataModel = await prompt('Enter new data model name (e.g. Item): ');
  if (!dataModel) { console.error('Data model name is required. Exiting.'); rl.close(); process.exit(2); }

  if (!projectName) projectName = await prompt('Enter Gradle project name (Optional, default: keep current): ');

  rl.close();

  const subDir = packageName.replace(/\./g, '/');
  const pkgLast = packageName.split('.').pop()!;

  const dataModelUpper = dataModel.charAt(0).toUpperCase() + dataModel.slice(1);
  const dataModelLower = dataModel.charAt(0).toLowerCase() + dataModel.slice(1);
  const dataModelAllLower = dataModel.toLowerCase();

  // ─── Move source directories ───────────────────────────────
  const srcTypeDirs = ['src/main', 'src/androidTest', 'src/test'];

  function findModuleSrcDirs(): string[] {
    const results: string[] = [];
    function walk(dir: string, depth: number) {
      if (depth > 5) return;
      if (!fs.existsSync(dir)) return;
      for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        if (!entry.isDirectory()) continue;
        const fullPath = path.join(dir, entry.name);
        if (srcTypeDirs.some(s => fullPath.endsWith(s))) {
          results.push(fullPath);
        } else {
          walk(fullPath, depth + 1);
        }
      }
    }
    walk('.', 0);
    return results;
  }

  console.log('Moving source directories...');
  for (const srcTypeDir of findModuleSrcDirs()) {
    for (const srcType of ['kotlin', 'java']) {
      const oldSrc = path.join(srcTypeDir, srcType, 'android', 'template');
      if (!fs.existsSync(oldSrc)) continue;

      const newDest = path.join(srcTypeDir, srcType, subDir);
      console.log(`  Creating ${newDest}`);
      fs.mkdirSync(newDest, { recursive: true });
      console.log(`  Moving files to ${newDest}`);
      copyDirRecursive(oldSrc, newDest);
      console.log(`  Removing old ${path.join(srcTypeDir, srcType, 'android')}`);
      removeRecursive(path.join(srcTypeDir, srcType, 'android'));
      removeEmptyDirs(path.join(srcTypeDir, srcType));
    }
  }

  // ─── Rename packages in .kt files ─────────────────────────
  console.log(`Renaming packages to ${packageName}`);
  const ktFiles = findFiles('.', f => f.endsWith('.kt'));
  for (const file of ktFiles) {
    replaceInFileMulti(file, [
      ['package android.template', `package ${packageName}`],
      ['import android.template', `import ${packageName}`],
    ]);
  }

  // ─── Rename android.template in .kts files ─────────────────
  const ktsFiles = findFiles('.', f => f.endsWith('.kts'));
  for (const file of ktsFiles) {
    replaceInFile(file, 'android.template', packageName);
  }

  // ─── Rename plugin IDs in build-logic ─────────────────────
  console.log('Renaming build-logic plugin IDs...');
  const buildLogicKtsFiles = findFiles('./build-logic', f => f.endsWith('.kts'));
  for (const file of buildLogicKtsFiles) {
    replaceInFileMulti(file, [
      [/template\.android/g, `${pkgLast}.android`],
      [/template\.hilt/g, `${pkgLast}.hilt`],
    ]);
  }
  const buildLogicKtFiles = findFiles('./build-logic', f => f.endsWith('.kt'));
  for (const file of buildLogicKtFiles) {
    replaceInFileMulti(file, [
      [/template\.android/g, `${pkgLast}.android`],
      [/template\.hilt/g, `${pkgLast}.hilt`],
    ]);
  }

  // Non build-logic .kts files — rename plugin references
  const nonBuildLogicKtsFiles = findFiles('.', f =>
    f.endsWith('.kts') && !f.includes(`${path.sep}build-logic${path.sep}`)
  );
  for (const file of nonBuildLogicKtsFiles) {
    replaceInFileMulti(file, [
      [/template\.android/g, `${pkgLast}.android`],
      [/template\.hilt/g, `${pkgLast}.hilt`],
    ]);
  }

  // ─── Rename in libs.versions.toml ─────────────────────────
  const tomlFiles = findFiles('./gradle', f => f.endsWith('.toml'));
  for (const file of tomlFiles) {
    replaceInFileMulti(file, [
      [/template\.android/g, `${pkgLast}.android`],
      [/template\.hilt/g, `${pkgLast}.hilt`],
      [/^template-android/gm, `${pkgLast}-android`],
      [/^template-hilt/gm, `${pkgLast}-hilt`],
    ]);
  }

  // ─── Rename model (Post → DataModel) ──────────────────────
  console.log(`Renaming model to ${dataModel}`);
  const allKtFiles = findFiles('.', f => f.endsWith('.kt') || f.endsWith('.kt'));
  for (const file of allKtFiles) {
    if (!fs.existsSync(file)) continue;
    replaceInFileMulti(file, [
      [/Post/g, dataModelUpper],
      [/post(?=[A-Z])/g, dataModelLower],
      [/\bpost\b/g, dataModelAllLower],
    ]);
  }

  // Clean up .bak files (none generated in TS, but just in case)
  for (const f of findFiles('.', f => f.endsWith('.bak'))) fs.unlinkSync(f);

  // ─── Rename Post* files ────────────────────────────────────
  console.log(`Renaming files to ${dataModel}`);
  if (dataModelUpper !== 'Post') {
    const postFiles = findFiles('.', f => path.basename(f).includes('Post') && f.endsWith('.kt'));
    for (const f of postFiles) {
      const newName = path.basename(f).replace(/Post/g, dataModelUpper);
      fs.renameSync(f, path.join(path.dirname(f), newName));
    }
  }

  // ─── Rename post/ directories ─────────────────────────────
  if (dataModelAllLower !== 'post') {
    console.log(`Renaming directories to ${dataModel}`);
    // Collect all 'post' directories (depth-first, leaves first)
    const postDirs = findDirs('.', d => path.basename(d) === 'post');
    // Sort by depth descending (deepest first) so we rename leaves before parents
    postDirs.sort((a, b) => b.split(path.sep).length - a.split(path.sep).length);
    for (const d of postDirs) {
      const newPath = path.join(path.dirname(d), dataModelAllLower);
      fs.renameSync(d, newPath);
    }
  }

  // ─── Set project name ─────────────────────────────────────
  const settingsFile = 'settings.gradle.kts';
  if (projectName && fs.existsSync(settingsFile)) {
    console.log(`Setting rootProject.name to "${projectName}"`);
    let content = fs.readFileSync(settingsFile, 'utf-8');
    content = content.replace(
      /^(rootProject\.name\s*=\s*).*/m,
      `$1"${projectName}"`
    );
    fs.writeFileSync(settingsFile, content);
  }

  // ─── Remove template-only files ───────────────────────────
  console.log('Removing additional files');
  const filesToRemove = [
    'CONTRIBUTING.md',
    'LICENSE',
    'README.md',
    'customizer.sh',
    'trim.sh',
    'scaffold.sh',
    'install-zshrc.sh',
  ];
  for (const f of filesToRemove) {
    if (fs.existsSync(f)) fs.unlinkSync(f);
  }

  console.log('Done!');
}

main().catch(err => {
  console.error(err);
  rl.close();
  process.exit(1);
});
