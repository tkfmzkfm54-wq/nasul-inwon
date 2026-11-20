-- 나는술로 인원관리 · 클라우드(Supabase) 서버 준비
--
-- 순서 (한 번만)
-- 1. supabase.com → New project. 리전은 Northeast Asia (Seoul).
-- 2. SQL Editor에 이 파일 전체를 붙여 넣고 Run. (다시 실행해도 됨)
-- 3. Authentication → Sign In / Providers → "Allow new users to sign up" 끄기. 운영진 계정은 직접 만든다.
-- 4. Authentication → Users → Add user → Create new user: 운영진 이메일·비밀번호, "Auto Confirm User" 체크.
-- 5. 맨 아래 '운영진 등록'의 이메일을 바꿔 SQL Editor에서 실행 (운영진마다 한 번).
--    등록 안 된 계정은 로그인해도 명단을 읽고 쓸 수 없다 (3번을 깜빡해도 막힘).
--    로그인했는데 ☁ 버튼이 "연결 안 됨"이면 이 등록부터 확인한다 (버튼에 마우스를 올리면 오류 내용이 보임).
-- 6. Project Settings → API Keys에서 Project URL과 Publishable key(sb_publishable_...)를
--    인원관리.html의 CLOUD_URL · CLOUD_KEY에 넣는다. Secret key(sb_secret_...)는 절대 넣지 않는다.
-- 7. 여러 폰에서 쓰려면 인원관리.html을 웹 주소로 올린다(GitHub Pages 등). 화면 위 ☁ 버튼으로 로그인.
--
-- 무료 플랜은 1주 넘게 아무도 안 쓰면 일시정지된다. 대시보드에서 Restore하면 다시 쓸 수 있고, 그동안 폰에서는 이 폰 사본으로 계속 쓸 수 있다.

-- 명단 전체를 한 줄에 둔다. rev는 올릴 때마다 1 증가: 오래된 폰이 남의 변경을 덮어쓰지 못하게 앱이 "rev가 그대로일 때만" 고친다.
create table if not exists public.app_state (
  id text primary key,
  data jsonb not null,
  rev integer not null default 1
);

-- 운영진 명단: 여기 있는 계정만 app_state를 읽고 쓴다.
create table if not exists public.editors (
  user_id uuid primary key references auth.users(id) on delete cascade,
  memo text
);

alter table public.app_state enable row level security;
alter table public.editors enable row level security;

-- 앱에서는 자기 줄만 볼 수 있다(아래 권한 확인용). 추가·삭제 정책은 없음 = 대시보드·SQL에서만 관리.
-- 이게 없으면 권한 확인의 select가 0줄이 되어 등록된 운영진도 막힌다.
drop policy if exists "본인 등록 확인" on public.editors;
create policy "본인 등록 확인" on public.editors for select to authenticated
  using (user_id = (select auth.uid()));
grant select on public.editors to authenticated;

drop policy if exists "운영진만" on public.app_state;
create policy "운영진만" on public.app_state for all to authenticated
  using (exists (select 1 from public.editors e where e.user_id = (select auth.uid())))
  with check (exists (select 1 from public.editors e where e.user_id = (select auth.uid())));

grant select, insert, update on public.app_state to authenticated;

-- 운영진 등록: 이메일을 바꿔 실행 (4번에서 만든 계정)
insert into public.editors (user_id, memo)
select id, email from auth.users where email = '운영진이메일@example.com'
on conflict (user_id) do nothing;
