#!/usr/bin/env tsx
/**
 * db.ts
 * Supabase JS 클라이언트로 스키마/테이블 목록을 조회합니다.
 *
 * .env 설정:
 *   SUPABASE_URL=https://choi-choi.duckdns.org:60001
 *   SUPABASE_SERVICE_ROLE_KEY=<service_role_key>
 *
 * 사용법:
 *   yarn db
 */
import { createClient } from '@supabase/supabase-js';

const SYSTEM_SCHEMAS = new Set([
  'pg_toast',
  'pg_catalog',
  'pg_temp_1',
  'pg_toast_temp_1',
  'information_schema',
]);

async function main() {
  const supabaseUrl = process.env.SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !serviceRoleKey) {
    console.error('❌ 환경변수가 필요합니다.');
    console.error('   SUPABASE_URL=...');
    console.error('   SUPABASE_SERVICE_ROLE_KEY=...');
    process.exit(1);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  console.log(`🔗 ${supabaseUrl}\n`);

  // ─── 스키마 목록 ───────────────────────────────────────────────────
  const { data: schemas, error: schemaErr } = await supabase
    .schema('information_schema')
    .from('schemata')
    .select('schema_name, schema_owner');

  if (schemaErr) throw new Error(`스키마 조회 실패: ${schemaErr.message}`);

  const userSchemas = schemas!.filter((s: { schema_name: string }) => !SYSTEM_SCHEMAS.has(s.schema_name));
  const hiddenCount = schemas!.length - userSchemas.length;

  console.log('━━━ 스키마 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  for (const s of userSchemas as { schema_name: string; schema_owner: string }[]) {
    console.log(`  ${s.schema_name.padEnd(32)} owner: ${s.schema_owner}`);
  }
  if (hiddenCount > 0) {
    console.log(`  (시스템 스키마 ${hiddenCount}개 숨김)`);
  }
  console.log(`\n  총 ${userSchemas.length}개 (시스템 제외)\n`);

  // ─── 테이블 · 뷰 목록 ──────────────────────────────────────────────
  const { data: tables, error: tableErr } = await supabase
    .schema('information_schema')
    .from('tables')
    .select('table_schema, table_name, table_type')
    .not('table_schema', 'in', `(${[...SYSTEM_SCHEMAS].join(',')})`)
    .order('table_schema')
    .order('table_name');

  if (tableErr) throw new Error(`테이블 조회 실패: ${tableErr.message}`);

  type TableRow = { table_schema: string; table_name: string; table_type: string };

  const bySchema = new Map<string, TableRow[]>();
  for (const row of tables as TableRow[]) {
    if (!bySchema.has(row.table_schema)) bySchema.set(row.table_schema, []);
    bySchema.get(row.table_schema)!.push(row);
  }

  console.log('━━━ 테이블 / 뷰 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  for (const [schema, rows] of bySchema) {
    const baseTables = rows.filter(r => r.table_type === 'BASE TABLE');
    const views      = rows.filter(r => r.table_type === 'VIEW');

    console.log(`\n  [${schema}]  (테이블 ${baseTables.length}개, 뷰 ${views.length}개)`);

    for (const r of baseTables) {
      console.log(`    ${r.table_name}`);
    }
    if (views.length > 0) {
      console.log(`    ── 뷰 ──`);
      for (const r of views) {
        console.log(`    ${r.table_name}`);
      }
    }
  }

  const totalTables = (tables as TableRow[]).filter(r => r.table_type === 'BASE TABLE').length;
  const totalViews  = (tables as TableRow[]).filter(r => r.table_type === 'VIEW').length;
  console.log(`\n  총 테이블 ${totalTables}개 · 뷰 ${totalViews}개\n`);
}

main().catch(err => {
  console.error('\n❌ 오류:', err.message);
  process.exit(1);
});
