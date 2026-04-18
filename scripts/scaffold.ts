#!/usr/bin/env tsx
import * as fs from 'fs';
import * as path from 'path';
import * as readline from 'readline';

// ─── Readline ──────────────────────────────────────────────────
const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

function prompt(question: string): Promise<string> {
  return new Promise(resolve => rl.question(question, resolve));
}

async function askYesNo(question: string, defaultYes = true): Promise<boolean> {
  const suffix = defaultYes ? ' [Y/n]: ' : ' [y/N]: ';
  const answer = await prompt(question + suffix);
  if (!answer.trim()) return defaultYes;
  return answer.trim().toLowerCase().startsWith('y');
}

// ─── Name transformations ──────────────────────────────────────
function toPascalCase(name: string): string {
  return name
    .toLowerCase()
    .replace(/[-_](.)/g, (_, c: string) => c.toUpperCase())
    .replace(/^(.)/, (c: string) => c.toUpperCase());
}

function toCamelCase(name: string): string {
  const pascal = toPascalCase(name);
  return pascal.charAt(0).toLowerCase() + pascal.slice(1);
}

function toPkgName(name: string): string {
  return name.toLowerCase().replace(/[-_]/g, '');
}

// ─── File helpers ──────────────────────────────────────────────
function fileContains(filePath: string, text: string): boolean {
  return fs.readFileSync(filePath, 'utf-8').includes(text);
}

function insertAfterLastMatch(filePath: string, searchText: string, newLine: string): void {
  const lines = fs.readFileSync(filePath, 'utf-8').split('\n');
  let lastIdx = -1;
  for (let i = lines.length - 1; i >= 0; i--) {
    if (lines[i].includes(searchText)) { lastIdx = i; break; }
  }
  if (lastIdx >= 0) {
    lines.splice(lastIdx + 1, 0, newLine);
    fs.writeFileSync(filePath, lines.join('\n'));
  } else {
    fs.appendFileSync(filePath, '\n' + newLine);
  }
}

function insertAfterLine(filePath: string, searchText: string, newLine: string): void {
  const lines = fs.readFileSync(filePath, 'utf-8').split('\n');
  const idx = lines.findIndex(l => l.includes(searchText));
  if (idx >= 0) {
    lines.splice(idx + 1, 0, newLine);
    fs.writeFileSync(filePath, lines.join('\n'));
  }
}

// ─── Repository func parsing/generation ───────────────────────
interface RepoFunc {
  funcName: string;
  params: string;
  returnType: string;
  isSuspend: boolean;
}

function parseRepoFunc(funcDef: string): RepoFunc {
  const arrowIdx = funcDef.lastIndexOf(' -> ');
  const funcPart = funcDef.slice(0, arrowIdx);
  let returnType = funcDef.slice(arrowIdx + 4).trim();

  const funcName = funcPart.replace(/\(.*/, '').trim();
  const paramsMatch = funcPart.match(/\((.*)\)$/s);
  const params = paramsMatch ? paramsMatch[1] || '' : '';

  let isSuspend = false;
  if (returnType.startsWith('suspend ')) {
    isSuspend = true;
    returnType = returnType.slice(8).trim();
  }

  return { funcName, params, returnType, isSuspend };
}

function buildKotlinParams(paramsStr: string): string {
  if (!paramsStr.trim()) return '';
  return paramsStr
    .split(',')
    .map(p => {
      const parts = p.trim().split(':');
      return `${parts[0].trim()}: ${parts.slice(1).join(':').trim()}`;
    })
    .join(', ');
}

function genRepoInterfaceFunc(funcDef: string): string {
  const { funcName, params, returnType, isSuspend } = parseRepoFunc(funcDef);
  const kotlinParams = buildKotlinParams(params);
  const paramsPart = kotlinParams ? `(${kotlinParams})` : '()';

  if (returnType.startsWith('Flow')) {
    return `    fun ${funcName}${paramsPart}: ${returnType}`;
  } else if (isSuspend) {
    return `    suspend fun ${funcName}${paramsPart}: ${returnType}`;
  } else {
    return `    fun ${funcName}${paramsPart}: ${returnType}`;
  }
}

function genRepoImplFunc(funcDef: string): string {
  const { funcName, params, returnType, isSuspend } = parseRepoFunc(funcDef);
  const kotlinParams = buildKotlinParams(params);
  const paramsPart = kotlinParams ? `(${kotlinParams})` : '()';
  const lines: string[] = [];

  if (returnType.startsWith('Flow')) {
    lines.push(`    override fun ${funcName}${paramsPart}: ${returnType} = flow {`);
    lines.push(`        // TODO: 데이터 로드`);
    lines.push(`        emit(emptyList())`);
    lines.push(`    }`);
  } else if (isSuspend) {
    lines.push(`    override suspend fun ${funcName}${paramsPart}: ${returnType} {`);
    lines.push(`        // TODO: 구현`);
    lines.push(`    }`);
  } else {
    lines.push(`    override fun ${funcName}${paramsPart}: ${returnType} {`);
    lines.push(`        // TODO: 구현`);
    lines.push(`    }`);
  }
  return lines.join('\n');
}

// ─── API func parsing/generation ──────────────────────────────
interface ApiParam {
  name: string;
  type: string;
  defaultValue?: string;
}

interface ApiFunc {
  httpMethod: string;
  apiPath: string;
  funcName: string;
  params: ApiParam[];
  returnType: string;
}

function parseApiFunc(funcDef: string): ApiFunc {
  const arrowIdx = funcDef.lastIndexOf(' -> ');
  const mainPart = funcDef.slice(0, arrowIdx).trim();
  const returnType = funcDef.slice(arrowIdx + 4).trim();

  const tokens = mainPart.match(/^(\S+)\s+(\S+)\s+(\w+)\((.*)\)$/s);
  if (!tokens) throw new Error(`Cannot parse API func: ${funcDef}`);
  const [, httpMethod, apiPath, funcName, paramsStr] = tokens;

  const params: ApiParam[] = [];
  if (paramsStr.trim()) {
    for (const p of paramsStr.split(',')) {
      const trimmed = p.trim();
      const colonIdx = trimmed.indexOf(':');
      const name = trimmed.slice(0, colonIdx).trim();
      const rest = trimmed.slice(colonIdx + 1).trim();
      const eqIdx = rest.indexOf('=');
      if (eqIdx >= 0) {
        params.push({ name, type: rest.slice(0, eqIdx).trim(), defaultValue: rest.slice(eqIdx + 1).trim() });
      } else {
        params.push({ name, type: rest });
      }
    }
  }

  return { httpMethod: httpMethod.toUpperCase(), apiPath, funcName, params, returnType };
}

function genApiImports(apiFuncDefs: string[]): string {
  const parsed = apiFuncDefs.map(parseApiFunc);
  const methods = new Set(parsed.map(f => f.httpMethod));
  const needsPath = parsed.some(f => f.apiPath.includes('{'));
  const needsQuery = parsed.some(f =>
    ['GET', 'DELETE'].includes(f.httpMethod) &&
    f.params.some(p => !f.apiPath.includes(`{${p.name}}`))
  );
  const needsBody = parsed.some(f =>
    ['POST', 'PUT', 'PATCH'].includes(f.httpMethod) &&
    f.params.some(p => !f.apiPath.includes(`{${p.name}}`))
  );

  const imports: string[] = [];
  if (methods.has('GET'))    imports.push('import retrofit2.http.GET');
  if (methods.has('POST'))   imports.push('import retrofit2.http.POST');
  if (methods.has('PUT'))    imports.push('import retrofit2.http.PUT');
  if (methods.has('DELETE')) imports.push('import retrofit2.http.DELETE');
  if (needsBody)  imports.push('import retrofit2.http.Body');
  if (needsPath)  imports.push('import retrofit2.http.Path');
  if (needsQuery) imports.push('import retrofit2.http.Query');

  return imports.join('\n');
}

function genApiFunc(funcDef: string): string {
  const { httpMethod, apiPath, funcName, params, returnType } = parseApiFunc(funcDef);
  const lines: string[] = [];
  lines.push(`    @${httpMethod}("${apiPath}")`);

  if (params.length === 0) {
    lines.push(`    suspend fun ${funcName}(): ${returnType}`);
  } else {
    const paramLines: string[] = [];
    for (const p of params) {
      const defaultPart = p.defaultValue !== undefined ? ` = ${p.defaultValue}` : '';
      if (apiPath.includes(`{${p.name}}`)) {
        paramLines.push(`        @Path("${p.name}") ${p.name}: ${p.type}${defaultPart}`);
      } else if (['POST', 'PUT', 'PATCH'].includes(httpMethod) && (p.name === 'body' || p.type.endsWith('Request'))) {
        paramLines.push(`        @Body ${p.name}: ${p.type}${defaultPart}`);
      } else {
        paramLines.push(`        @Query("${p.name}") ${p.name}: ${p.type}${defaultPart}`);
      }
    }
    lines.push(`    suspend fun ${funcName}(`);
    paramLines.forEach((l, i) => lines.push(l + (i < paramLines.length - 1 ? ',' : '')));
    lines.push(`    ): ${returnType}`);
  }

  return lines.join('\n');
}

// ─── Main ──────────────────────────────────────────────────────
async function main() {
  const projectRoot = path.resolve(__dirname, '..');
  if (!fs.existsSync(path.join(projectRoot, 'settings.gradle.kts'))) {
    console.error('❌ settings.gradle.kts를 찾을 수 없습니다. 프로젝트 루트에서 실행하세요.');
    process.exit(1);
  }
  process.chdir(projectRoot);

  // Detect base package
  let basePkg = 'android.template';
  const coreModelBuild = path.join(projectRoot, 'core/model/build.gradle.kts');
  if (fs.existsSync(coreModelBuild)) {
    const content = fs.readFileSync(coreModelBuild, 'utf-8');
    const match = content.match(/namespace\s*=\s*"(.+)\.core\.model"/);
    if (match) basePkg = match[1];
  }
  const baseDir = basePkg.replace(/\./g, '/');

  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('  Feature Scaffold Generator');
  console.log(`  패키지: ${basePkg}`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  // Feature name
  let name = process.argv[2] || '';
  if (!name) name = await prompt('Feature 이름을 입력하세요 (예: comment, user-profile): ');
  if (!name.trim()) {
    console.error('❌ Feature 이름은 필수입니다.');
    rl.close(); process.exit(1);
  }
  name = name.trim();

  const nameUpper = toPascalCase(name);
  const nameCamel = toCamelCase(name);
  const nameKebab = name.toLowerCase();
  const namePkg = toPkgName(name);

  console.log('\n  이름 변환 확인:');
  console.log(`    PascalCase : ${nameUpper}`);
  console.log(`    camelCase  : ${nameCamel}`);
  console.log(`    패키지     : ${namePkg}\n`);

  // Layer selection
  console.log('━━━ 생성할 레이어를 선택하세요 ━━━\n');
  const doModel      = await askYesNo(`  1. core/model      — ${nameUpper} 도메인 모델`);
  const doNetwork    = await askYesNo(`  2. core/network    — \${API_NAME} + DTO`);
  const doData       = await askYesNo(`  3. core/data       — \${REPO_NAME}`);
  const doFeatureApi = await askYesNo(`  4. feature/${nameKebab}/api  — NavKey + Navigator 확장`);
  const doFeatureImpl = await askYesNo(`  5. feature/${nameKebab}/impl — ViewModel + Screen + Entry`);
  console.log('');

  if (!doModel && !doNetwork && !doData && !doFeatureApi && !doFeatureImpl) {
    console.log('아무 레이어도 선택하지 않았습니다. 종료합니다.');
    rl.close(); return;
  }

  // NavKey setup
  let navArgName = '';
  let navArgType = '';
  let navKeyType = 'data object';
  let navFuncName = `navigateTo${nameUpper}`;

  if (doFeatureApi) {
    console.log('');
    const navFuncInput = await prompt(`  나침반(navigateTo) 함수 이름을 입력하세요 (기본: ${navFuncName}): `);
    if (navFuncInput.trim()) navFuncName = navFuncInput.trim();

    const navArgInput = await prompt('  NavKey에 전달할 인자가 있나요? (예: postId:Int, 없으면 Enter): ');
    if (navArgInput.trim()) {
      const colonIdx = navArgInput.indexOf(':');
      navArgName = navArgInput.slice(0, colonIdx).trim();
      navArgType = navArgInput.slice(colonIdx + 1).trim();
      navKeyType = 'data class';
    }
  }

  // API setup
  const apiFuncs: string[] = [];
  let apiName = `${nameUpper}Api`;

  if (doNetwork) {
    console.log('\n━━━ API 설정 ━━━');
    const apiNameInput = await prompt(`  API 인터페이스 이름을 입력하세요 (기본: ${apiName}): `);
    if (apiNameInput.trim()) apiName = apiNameInput.trim();

    console.log('\n  API 함수를 추가하세요. (빈 줄 입력 시 종료)');
    while (true) {
      const fName = await prompt(`  함수명 (예: get${nameUpper}): `);
      if (!fName.trim()) break;
      const fMethod = await prompt('  HTTP 메소드 (예: GET, POST): ');
      const fPath   = await prompt(`  경로 (예: ${nameCamel}s/{id}): `);
      const fParams = await prompt('  파라미터 (예: id:Int, 없으면 빈칸): ');
      const fReturn = await prompt(`  반환타입 (예: ${nameUpper}Network): `);
      const funcDef = `${fMethod.toUpperCase().trim()} ${fPath.trim()} ${fName.trim()}(${fParams.trim()}) -> ${fReturn.trim()}`;
      apiFuncs.push(funcDef);
      console.log(`  → 추가됨: ${funcDef}\n`);
    }

    if (apiFuncs.length === 0) {
      console.log('  기본 API 함수를 생성합니다.');
      apiFuncs.push(`GET ${nameCamel}s get${nameUpper}s(limit:Int=30,skip:Int=0) -> ${nameUpper}sResponse`);
      apiFuncs.push(`GET ${nameCamel}s/{id} get${nameUpper}(id:Int) -> ${nameUpper}Network`);
    }
  }

  // Repository setup
  const repoFuncs: string[] = [];
  let repoName = `${nameUpper}Repository`;

  if (doData) {
    console.log('\n━━━ Repository 설정 ━━━');
    const repoNameInput = await prompt(`  Repository 인터페이스 이름을 입력하세요 (기본: ${repoName}): `);
    if (repoNameInput.trim()) repoName = repoNameInput.trim();

    console.log('\n  Repository 함수를 추가하세요. (빈 줄 입력 시 종료)');
    while (true) {
      const fName = await prompt(`  함수명 (예: get${nameUpper}): `);
      if (!fName.trim()) break;
      const fParams = await prompt('  파라미터 (예: id:Int, 없으면 빈칸): ');
      const fReturn = await prompt(`  반환타입 (예: Flow<List<${nameUpper}>>, suspend ${nameUpper} 등): `);
      const funcDef = `${fName.trim()}(${fParams.trim()}) -> ${fReturn.trim()}`;
      repoFuncs.push(funcDef);
      console.log(`  → 추가됨: ${funcDef}\n`);
    }

    if (repoFuncs.length === 0) {
      console.log('  기본 Repository 함수를 생성합니다.');
      repoFuncs.push(`${nameCamel}s() -> Flow<List<${nameUpper}>>`);
    }
  }

  const repoNameCamel = toCamelCase(repoName);
  const apiNameCamel = toCamelCase(apiName);
  const created: string[] = [];

  // ─── 1. core/model ─────────────────────────────────────────
  if (doModel) {
    const dir = `core/model/src/main/kotlin/${baseDir}/core/model`;
    fs.mkdirSync(dir, { recursive: true });
    const file = `${dir}/${nameUpper}.kt`;
    if (fs.existsSync(file)) {
      console.log(`⚠️  ${file} 이미 존재합니다. 건너뜁니다.`);
    } else {
      fs.writeFileSync(file, [
        `package ${basePkg}.core.model`,
        '',
        `data class ${nameUpper}(`,
        `    val id: Int,`,
        `    // TODO: 도메인 필드를 추가하세요`,
        `)`,
        '',
      ].join('\n'));
      created.push(file);
    }
  }

  // ─── 2. core/network ───────────────────────────────────────
  if (doNetwork) {
    const netDir = `core/network/src/main/kotlin/${baseDir}/core/network/api`;
    fs.mkdirSync(netDir, { recursive: true });

    // DTO
    const dtoFile = `${netDir}/${nameUpper}Network.kt`;
    if (fs.existsSync(dtoFile)) {
      console.log(`⚠️  ${dtoFile} 이미 존재합니다. 건너뜁니다.`);
    } else {
      fs.writeFileSync(dtoFile, [
        `package ${basePkg}.core.network.api`,
        '',
        `import ${basePkg}.core.model.${nameUpper}`,
        '',
        `data class ${nameUpper}sResponse(`,
        `    val ${nameCamel}s: List<${nameUpper}Network>,`,
        `    val total: Int,`,
        `    val skip: Int,`,
        `    val limit: Int,`,
        `)`,
        '',
        `data class ${nameUpper}Network(`,
        `    val id: Int,`,
        `    // TODO: 서버 응답 필드를 추가하세요`,
        `)`,
        '',
        `fun ${nameUpper}Network.toDomain(): ${nameUpper} = ${nameUpper}(`,
        `    id = id,`,
        `    // TODO: 필드 매핑`,
        `)`,
        '',
      ].join('\n'));
      created.push(dtoFile);
    }

    // API interface
    const apiFile = `${netDir}/${apiName}.kt`;
    if (fs.existsSync(apiFile)) {
      console.log(`⚠️  ${apiFile} 이미 존재합니다. 건너뜁니다.`);
    } else {
      const apiFuncLines = apiFuncs.flatMap((f, i) => {
        const funcCode = genApiFunc(f);
        return i > 0 ? ['', funcCode] : [funcCode];
      });

      fs.writeFileSync(apiFile, [
        `package ${basePkg}.core.network.api`,
        '',
        genApiImports(apiFuncs),
        '',
        `interface ${apiName} {`,
        ...apiFuncLines,
        `}`,
        '',
      ].join('\n'));
      created.push(apiFile);
    }

    console.log(`\n📌 NetworkModule.kt에 아래 provider를 추가하세요:\n`);
    console.log(`    @Provides`);
    console.log(`    @Singleton`);
    console.log(`    fun provide${apiName}(retrofit: Retrofit): ${apiName} {`);
    console.log(`        return retrofit.create(${apiName}::class.java)`);
    console.log(`    }\n`);
  }

  // ─── 3. core/data ──────────────────────────────────────────
  if (doData) {
    const dataDir = `core/data/src/main/kotlin/${baseDir}/core/data`;
    fs.mkdirSync(dataDir, { recursive: true });

    const repoFile = `${dataDir}/${repoName}.kt`;
    if (fs.existsSync(repoFile)) {
      console.log(`⚠️  ${repoFile} 이미 존재합니다. 건너뜁니다.`);
    } else {
      const needsFlow = repoFuncs.some(f => f.includes('Flow'));
      const interfaceFuncs = repoFuncs.flatMap((f, i) =>
        i > 0 ? ['', genRepoInterfaceFunc(f)] : [genRepoInterfaceFunc(f)]
      );
      const implFuncs = repoFuncs.flatMap((f, i) =>
        i > 0 ? ['', genRepoImplFunc(f)] : [genRepoImplFunc(f)]
      );

      const lines: string[] = [
        `package ${basePkg}.core.data`,
        '',
        `import ${basePkg}.core.model.${nameUpper}`,
      ];
      if (doNetwork) {
        lines.push(`import ${basePkg}.core.network.api.${apiName}`);
        lines.push(`import ${basePkg}.core.network.api.toDomain`);
      }
      if (needsFlow) {
        lines.push(`import kotlinx.coroutines.flow.Flow`);
        lines.push(`import kotlinx.coroutines.flow.flow`);
      }
      lines.push(`import javax.inject.Inject`);
      lines.push('');
      lines.push(`interface ${repoName} {`);
      lines.push(...interfaceFuncs);
      lines.push(`}`);
      lines.push('');
      if (doNetwork) {
        lines.push(`class Default${repoName} @Inject constructor(`);
        lines.push(`    private val ${apiNameCamel}: ${apiName},`);
        lines.push(`) : ${repoName} {`);
      } else {
        lines.push(`class Default${repoName} @Inject constructor(`);
        lines.push(`    // TODO: 데이터 소스 주입`);
        lines.push(`) : ${repoName} {`);
      }
      lines.push('');
      lines.push(...implFuncs);
      lines.push(`}`);
      lines.push('');

      fs.writeFileSync(repoFile, lines.join('\n'));
      created.push(repoFile);
    }

    console.log(`\n📌 DataModule.kt에 아래 바인딩을 추가하세요:\n`);
    console.log(`    @Singleton`);
    console.log(`    @Binds`);
    console.log(`    fun binds${repoName}(`);
    console.log(`        ${repoNameCamel}: Default${repoName}`);
    console.log(`    ): ${repoName}\n`);
  }

  // ─── 4. feature/xxx/api ────────────────────────────────────
  if (doFeatureApi) {
    const apiModDir = `feature/${nameKebab}/api`;
    const apiSrcDir = `${apiModDir}/src/main/kotlin/${baseDir}/feature/${namePkg}/navigation`;
    fs.mkdirSync(apiSrcDir, { recursive: true });

    const buildFile = `${apiModDir}/build.gradle.kts`;
    if (!fs.existsSync(buildFile)) {
      fs.writeFileSync(buildFile, [
        `plugins {`,
        `    alias(libs.plugins.template.android.feature.navigation)`,
        `}`,
        '',
        `android {`,
        `    namespace = "${basePkg}.feature.${namePkg}.api"`,
        '',
        `    defaultConfig {`,
        `        consumerProguardFiles("consumer-rules.pro")`,
        `    }`,
        `}`,
        '',
        `dependencies {`,
        `    api(projects.core.navigation)`,
        `}`,
        '',
      ].join('\n'));
      created.push(buildFile);
    }

    const navKeyFile = `${apiSrcDir}/${nameUpper}NavKey.kt`;
    if (!fs.existsSync(navKeyFile)) {
      const lines: string[] = [
        `package ${basePkg}.feature.${namePkg}.navigation`,
        '',
        `import ${basePkg}.core.navigation.Navigator`,
        `import androidx.navigation3.runtime.NavKey`,
        `import kotlinx.serialization.Serializable`,
        '',
        `@Serializable`,
      ];

      if (navArgName) {
        lines.push(`${navKeyType} ${nameUpper}NavKey(val ${navArgName}: ${navArgType}) : NavKey`);
        lines.push('');
        lines.push(`fun Navigator.${navFuncName}(${navArgName}: ${navArgType}) {`);
        lines.push(`    navigate(${nameUpper}NavKey(${navArgName}))`);
        lines.push(`}`);
      } else {
        lines.push(`data object ${nameUpper}NavKey : NavKey`);
        lines.push('');
        lines.push(`fun Navigator.${navFuncName}() {`);
        lines.push(`    navigate(${nameUpper}NavKey)`);
        lines.push(`}`);
      }
      lines.push('');

      fs.writeFileSync(navKeyFile, lines.join('\n'));
      created.push(navKeyFile);
    }

    const settingsFile = 'settings.gradle.kts';
    if (!fileContains(settingsFile, `feature:${nameKebab}:api`)) {
      insertAfterLastMatch(settingsFile, 'include(":feature:', `include(":feature:${nameKebab}:api")`);
    }
  }

  // ─── 5. feature/xxx/impl ───────────────────────────────────
  if (doFeatureImpl) {
    const implModDir = `feature/${nameKebab}/impl`;
    const uiDir  = `${implModDir}/src/main/kotlin/${baseDir}/feature/${namePkg}/ui`;
    const navDir = `${implModDir}/src/main/kotlin/${baseDir}/feature/${namePkg}/navigation`;
    const testDir = `${implModDir}/src/test/kotlin/${baseDir}/feature/${namePkg}/ui`;
    fs.mkdirSync(uiDir, { recursive: true });
    fs.mkdirSync(navDir, { recursive: true });
    fs.mkdirSync(testDir, { recursive: true });

    const implBuild = `${implModDir}/build.gradle.kts`;
    if (!fs.existsSync(implBuild)) {
      const extraDeps = doData ? `    implementation(projects.core.data)\n` : '';
      fs.writeFileSync(implBuild, [
        `plugins {`,
        `    alias(libs.plugins.template.android.feature)`,
        `}`,
        '',
        `android {`,
        `    namespace = "${basePkg}.feature.${namePkg}"`,
        '',
        `    defaultConfig {`,
        `        testInstrumentationRunner = "${basePkg}.core.testing.HiltTestRunner"`,
        `        consumerProguardFiles("consumer-rules.pro")`,
        `    }`,
        `}`,
        '',
        `dependencies {`,
        `${extraDeps}    implementation(projects.core.ui)`,
        `    implementation(projects.core.navigation)`,
        `    implementation(projects.feature.${nameCamel}.api)`,
        '',
        `    androidTestImplementation(projects.core.testing)`,
        '',
        `    implementation(libs.androidx.activity.compose)`,
        `    implementation(libs.androidx.hilt.lifecycle.viewmodel.compose)`,
        '',
        `    implementation(libs.androidx.compose.ui)`,
        `    implementation(libs.androidx.compose.material3)`,
        `    implementation(libs.androidx.compose.material.icons.extended)`,
        '',
        `    androidTestImplementation(libs.hilt.android.testing)`,
        `    kspAndroidTest(libs.hilt.compiler)`,
        `    testImplementation(libs.hilt.android.testing)`,
        `    kspTest(libs.hilt.compiler)`,
        '',
        `    androidTestImplementation(libs.androidx.test.ext.junit)`,
        `    androidTestImplementation(libs.androidx.test.runner)`,
        `    androidTestImplementation(libs.androidx.compose.ui.test.junit4)`,
        `    debugImplementation(libs.androidx.compose.ui.test.manifest)`,
        `}`,
        '',
      ].join('\n'));
      created.push(implBuild);
    }

    // UiState + ViewModel
    const vmFile = `${uiDir}/${nameUpper}ViewModel.kt`;
    if (!fs.existsSync(vmFile)) {
      // Find first Flow-typed repo function with no params
      let firstFlowFunc = '';
      if (doData) {
        for (const f of repoFuncs) {
          if (f.includes('Flow')) {
            const { funcName, params } = parseRepoFunc(f);
            if (!params.trim()) { firstFlowFunc = funcName; break; }
          }
        }
      }

      const lines: string[] = [`package ${basePkg}.feature.${namePkg}.ui`, ''];
      if (doData) lines.push(`import ${basePkg}.core.data.${repoName}`);
      lines.push(`import ${basePkg}.core.model.${nameUpper}`);
      lines.push(`import androidx.lifecycle.ViewModel`);

      if (doData && firstFlowFunc) {
        lines.push(
          `import androidx.lifecycle.viewModelScope`,
          `import dagger.hilt.android.lifecycle.HiltViewModel`,
          `import kotlinx.coroutines.flow.SharingStarted`,
          `import kotlinx.coroutines.flow.StateFlow`,
          `import kotlinx.coroutines.flow.catch`,
          `import kotlinx.coroutines.flow.map`,
          `import kotlinx.coroutines.flow.stateIn`,
          `import javax.inject.Inject`,
          '',
          `@HiltViewModel`,
          `class ${nameUpper}ViewModel @Inject constructor(`,
          `    private val ${repoNameCamel}: ${repoName},`,
          `) : ViewModel() {`,
          '',
          `    val uiState: StateFlow<${nameUpper}UiState> = ${repoNameCamel}`,
          `        .${firstFlowFunc}()`,
          `        .map<List<${nameUpper}>, ${nameUpper}UiState> { ${nameUpper}UiState.Success(it) }`,
          `        .catch { emit(${nameUpper}UiState.Error(it)) }`,
          `        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ${nameUpper}UiState.Loading)`,
          `}`,
        );
      } else if (doData) {
        lines.push(
          `import dagger.hilt.android.lifecycle.HiltViewModel`,
          `import kotlinx.coroutines.flow.MutableStateFlow`,
          `import kotlinx.coroutines.flow.StateFlow`,
          `import kotlinx.coroutines.flow.asStateFlow`,
          `import javax.inject.Inject`,
          '',
          `@HiltViewModel`,
          `class ${nameUpper}ViewModel @Inject constructor(`,
          `    private val ${repoNameCamel}: ${repoName},`,
          `) : ViewModel() {`,
          '',
          `    private val _uiState = MutableStateFlow<${nameUpper}UiState>(${nameUpper}UiState.Loading)`,
          `    val uiState: StateFlow<${nameUpper}UiState> = _uiState.asStateFlow()`,
          '',
          `    // TODO: repository 함수를 호출하여 데이터 로드`,
          `}`,
        );
      } else {
        lines.push(
          `import dagger.hilt.android.lifecycle.HiltViewModel`,
          `import kotlinx.coroutines.flow.MutableStateFlow`,
          `import kotlinx.coroutines.flow.StateFlow`,
          `import kotlinx.coroutines.flow.asStateFlow`,
          `import javax.inject.Inject`,
          '',
          `@HiltViewModel`,
          `class ${nameUpper}ViewModel @Inject constructor() : ViewModel() {`,
          '',
          `    private val _uiState = MutableStateFlow<${nameUpper}UiState>(${nameUpper}UiState.Loading)`,
          `    val uiState: StateFlow<${nameUpper}UiState> = _uiState.asStateFlow()`,
          '',
          `    // TODO: 데이터 로드 로직 구현`,
          `}`,
        );
      }

      lines.push(
        '',
        `sealed interface ${nameUpper}UiState {`,
        `    data object Loading : ${nameUpper}UiState`,
        `    data class Error(val throwable: Throwable) : ${nameUpper}UiState`,
        `    data class Success(val data: List<${nameUpper}>) : ${nameUpper}UiState`,
        `}`,
        '',
      );

      fs.writeFileSync(vmFile, lines.join('\n'));
      created.push(vmFile);
    }

    // Screen
    const screenFile = `${uiDir}/${nameUpper}Screen.kt`;
    if (!fs.existsSync(screenFile)) {
      fs.writeFileSync(screenFile, [
        `package ${basePkg}.feature.${namePkg}.ui`,
        '',
        `import ${basePkg}.core.model.${nameUpper}`,
        `import androidx.compose.foundation.layout.Arrangement`,
        `import androidx.compose.foundation.layout.Box`,
        `import androidx.compose.foundation.layout.Column`,
        `import androidx.compose.foundation.layout.PaddingValues`,
        `import androidx.compose.foundation.layout.fillMaxSize`,
        `import androidx.compose.foundation.layout.fillMaxWidth`,
        `import androidx.compose.foundation.layout.padding`,
        `import androidx.compose.foundation.lazy.LazyColumn`,
        `import androidx.compose.foundation.lazy.items`,
        `import androidx.compose.material3.Card`,
        `import androidx.compose.material3.CircularProgressIndicator`,
        `import androidx.compose.material3.MaterialTheme`,
        `import androidx.compose.material3.Text`,
        `import androidx.compose.runtime.Composable`,
        `import androidx.compose.runtime.getValue`,
        `import androidx.compose.ui.Alignment`,
        `import androidx.compose.ui.Modifier`,
        `import androidx.compose.ui.unit.dp`,
        `import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel`,
        `import androidx.lifecycle.compose.collectAsStateWithLifecycle`,
        '',
        `@Composable`,
        `fun ${nameUpper}Screen(`,
        `    onBack: () -> Unit,`,
        `    modifier: Modifier = Modifier,`,
        `    viewModel: ${nameUpper}ViewModel = hiltViewModel(),`,
        `) {`,
        `    val uiState by viewModel.uiState.collectAsStateWithLifecycle()`,
        `    ${nameUpper}Content(state = uiState, modifier = modifier)`,
        `}`,
        '',
        `@Composable`,
        `private fun ${nameUpper}Content(`,
        `    state: ${nameUpper}UiState,`,
        `    modifier: Modifier = Modifier,`,
        `) {`,
        `    when (state) {`,
        `        is ${nameUpper}UiState.Loading -> {`,
        `            Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {`,
        `                CircularProgressIndicator()`,
        `            }`,
        `        }`,
        `        is ${nameUpper}UiState.Error -> {`,
        `            Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {`,
        `                Text(text = "Error: \${state.throwable.message}")`,
        `            }`,
        `        }`,
        `        is ${nameUpper}UiState.Success -> {`,
        `            LazyColumn(`,
        `                modifier = modifier,`,
        `                verticalArrangement = Arrangement.spacedBy(8.dp),`,
        `                contentPadding = PaddingValues(16.dp),`,
        `            ) {`,
        `                items(state.data, key = { it.id }) { item ->`,
        `                    ${nameUpper}Item(item)`,
        `                }`,
        `            }`,
        `        }`,
        `    }`,
        `}`,
        '',
        `@Composable`,
        `private fun ${nameUpper}Item(`,
        `    ${nameCamel}: ${nameUpper},`,
        `    modifier: Modifier = Modifier,`,
        `) {`,
        `    Card(modifier = modifier.fillMaxWidth()) {`,
        `        Column(Modifier.padding(16.dp)) {`,
        `            Text(`,
        `                text = "Item #\${${nameCamel}.id}",`,
        `                style = MaterialTheme.typography.titleSmall,`,
        `            )`,
        `            // TODO: 필드에 맞게 UI 구현`,
        `        }`,
        `    }`,
        `}`,
        '',
      ].join('\n'));
      created.push(screenFile);
    }

    // Navigation Entry
    const entryFile = `${navDir}/${nameUpper}Navigation.kt`;
    if (!fs.existsSync(entryFile) && doFeatureApi) {
      fs.writeFileSync(entryFile, [
        `package ${basePkg}.feature.${namePkg}.navigation`,
        '',
        `import ${basePkg}.core.navigation.Navigator`,
        `import ${basePkg}.feature.${namePkg}.ui.${nameUpper}Screen`,
        `import androidx.compose.foundation.layout.padding`,
        `import androidx.compose.runtime.Composable`,
        `import androidx.compose.ui.Modifier`,
        `import androidx.compose.ui.unit.dp`,
        `import androidx.navigation3.runtime.EntryProviderScope`,
        `import androidx.navigation3.runtime.NavKey`,
        '',
        `@Composable`,
        `fun EntryProviderScope<NavKey>.${nameUpper}Entry(navigator: Navigator) {`,
        `    entry<${nameUpper}NavKey> {`,
        `        ${nameUpper}Screen(`,
        `            onBack = navigator::back,`,
        `            modifier = Modifier.padding(16.dp),`,
        `        )`,
        `    }`,
        `}`,
        '',
      ].join('\n'));
      created.push(entryFile);
    }

    // settings.gradle.kts
    const settingsFile = 'settings.gradle.kts';
    if (!fileContains(settingsFile, `feature:${nameKebab}:impl`)) {
      if (fileContains(settingsFile, `feature:${nameKebab}:api`)) {
        insertAfterLine(settingsFile, `feature:${nameKebab}:api`, `include(":feature:${nameKebab}:impl")`);
      } else {
        insertAfterLastMatch(settingsFile, 'include(":feature:', `include(":feature:${nameKebab}:impl")`);
      }
    }
  }

  // ─── App module integration ─────────────────────────────────
  if (doFeatureApi || doFeatureImpl) {
    const appBuild = 'app/build.gradle.kts';
    if (fs.existsSync(appBuild)) {
      console.log(`📌 ${appBuild} 에 의존성을 추가합니다...`);
      if (doFeatureApi && !fileContains(appBuild, `projects.feature.${nameKebab}.api`)) {
        insertAfterLine(appBuild, 'projects.core.navigation', `    implementation(projects.feature.${nameKebab}.api)`);
      }
      if (doFeatureImpl && !fileContains(appBuild, `projects.feature.${nameKebab}.impl`)) {
        insertAfterLine(appBuild, 'projects.core.navigation', `    implementation(projects.feature.${nameKebab}.impl)`);
      }
    }

    const navFile = `app/src/main/kotlin/${baseDir}/ui/Navigation.kt`;
    if (fs.existsSync(navFile)) {
      console.log(`📌 ${navFile} 에 Navigation Entry를 등록합니다...`);
      if (!fileContains(navFile, `.feature.${namePkg}.navigation.${nameUpper}Entry`)) {
        insertAfterLine(navFile,
          'import.*feature.post.navigation.PostEntry',
          `import ${basePkg}.feature.${namePkg}.navigation.${nameUpper}Entry`
        );
      }
      if (!fileContains(navFile, `${nameUpper}Entry(navigator = navigator)`)) {
        insertAfterLine(navFile,
          'entryProvider {',
          `            ${nameUpper}Entry(navigator = navigator)`
        );
      }
    }
  }

  // ─── Summary ────────────────────────────────────────────────
  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('  ✅ 생성 완료');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  if (created.length > 0) {
    console.log('  생성된 파일:');
    for (const f of created) console.log(`    + ${f}`);
  } else {
    console.log('  새로 생성된 파일 없음 (모두 이미 존재)');
  }

  console.log('\n━━━ 남은 수동 작업 ━━━\n');
  if (doNetwork)      console.log(`  1. NetworkModule.kt에 provide${apiName}() 추가`);
  if (doData)         console.log(`  2. DataModule.kt에 binds${repoName}() 추가`);
  if (doFeatureImpl)  console.log('  (의존성 및 Navigation Entry 등록은 자동으로 시도되었습니다.)');
  if (doFeatureImpl)  console.log('  3. app/build.gradle.kts 확인');
  if (doFeatureImpl)  console.log('  4. app Navigation.kt 확인');
  console.log('\n  📖 자세한 절차: docs/feature-development-guide.md\n');

  rl.close();
}

main().catch(err => {
  console.error(err);
  rl.close();
  process.exit(1);
});
