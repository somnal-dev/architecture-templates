#!/usr/bin/env tsx
/**
 * db.ts
 * @supabase/supabase-js 로 app 스키마 테이블에 접근하는 예제입니다.
 *
 * 전제 조건:
 *   - Supabase Studio SQL Editor에서 app 스키마 생성 쿼리 실행
 *   - app 스키마에 테이블이 존재해야 함
 *
 * .env 설정:
 *   SUPABASE_URL=https://choi-choi.duckdns.org:60001
 *   SUPABASE_SERVICE_ROLE_KEY=<service_role_key>
 *
 * 사용법:
 *   yarn db
 */
import { createClient } from '@supabase/supabase-js';

// ─── 타입 정의 ──────────────────────────────────────────────────────────────
// app 스키마 테이블 타입을 여기에 정의합니다.
// 예시: projects 테이블
interface Project {
  id: number;
  name: string;
  description: string | null;
  created_at: string;
}

async function main() {
  const supabaseUrl = process.env.SUPABASE_URL!;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

  // ─── 클라이언트 생성 ──────────────────────────────────────────────────────
  // service_role 키: RLS 우회, 모든 데이터 접근 가능 (서버 전용)
  // anon 키: RLS 적용, 클라이언트 앱에서 사용
  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
    db: { schema: 'app' },          // 기본 스키마를 app으로 설정
  });

  // ─── app 스키마 기본 접근 ─────────────────────────────────────────────────
  // db.schema 를 'app' 으로 설정했으므로 바로 from() 사용 가능
  const { data: projects, error } = await supabase
    .from('projects')               // app.projects
    .select('*')
    .order('created_at', { ascending: false })
    .limit(10);

  if (error) {
    console.error('조회 실패:', error.message);
    return;
  }

  console.log('app.projects:', projects);

  // ─── 다른 스키마 접근 ─────────────────────────────────────────────────────
  // 기본값과 다른 스키마는 .schema() 로 전환
  const { data: authUsers } = await supabase
    .schema('auth')
    .from('users')
    .select('id, email, created_at')
    .limit(5);

  console.log('auth.users:', authUsers);

  // ─── INSERT 예시 ──────────────────────────────────────────────────────────
  // const { data: newProject, error: insertError } = await supabase
  //   .from('projects')
  //   .insert({ name: '새 프로젝트', description: '설명' })
  //   .select()
  //   .single();

  // ─── UPDATE 예시 ──────────────────────────────────────────────────────────
  // const { error: updateError } = await supabase
  //   .from('projects')
  //   .update({ description: '수정된 설명' })
  //   .eq('id', 1);

  // ─── DELETE 예시 ──────────────────────────────────────────────────────────
  // const { error: deleteError } = await supabase
  //   .from('projects')
  //   .delete()
  //   .eq('id', 1);
}

main().catch(err => {
  console.error('❌ 오류:', err.message);
  process.exit(1);
});
