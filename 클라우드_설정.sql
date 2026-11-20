-- 나는술로 인원관리 · 클라우드(Supabase) 서버 준비
--
-- 누구나: 주소만 알면 로그인 없이 서버 명단을 본다(보기 전용). 고치기는 마스터 비밀번호로 로그인한 사람만.
--
-- 순서 (한 번만)
-- 1. supabase.com → New project. 리전은 Northeast Asia (Seoul).
-- 2. SQL Editor에 이 파일 전체를 붙여 넣고 Run. (다시 실행해도 됨)
-- 3. Authentication → Sign In / Providers → "Allow new users to sign up" 끄기. 계정은 대시보드에서만 만든다.
-- 4. Authentication → Users → Add user → Create new user: 이메일은 인원관리.html의 CLOUD_MASTER_EMAIL
--    (nasul.master@example.com, 메일이 실제로 가지 않는 주소), 비밀번호는 마스터 비밀번호, "Auto Confirm User" 체크.
-- 5. 맨 아래 '마스터 등록'을 SQL Editor에서 실행. 등록 안 된 계정은 로그인해도 명단을 고칠 수 없다.
--    로그인했는데 ☁ 버튼이 "연결 안 됨"이면 이 등록부터 확인한다 (버튼에 마우스를 올리면 오류 내용이 보임).
-- 6. Project Settings → API Keys에서 Project URL과 Publishable key(sb_publishable_...)를
--    인원관리.html의 CLOUD_URL · CLOUD_KEY에 넣는다. Secret key(sb_secret_...)는 절대 넣지 않는다.
-- 7. 인원관리.html을 웹 주소로 올린다(GitHub Pages). 화면 위 ☁ 버튼에 마스터 비밀번호를 넣어 로그인.
--
-- 마스터 비밀번호는 로그인한 상태에서 ☁ 버튼 → "새 비밀번호"로 앱 안에서 바꾼다.
-- 잊었으면: Users에서 마스터 계정을 지우고 4·5번을 다시 한다 (비밀번호 찾기 메일은 쓰지 않음).
-- 무료 플랜은 1주 넘게 아무도 안 쓰면 일시정지된다. 대시보드에서 Restore하면 다시 쓸 수 있고, 그동안 폰에서는 이 폰 사본으로 계속 쓸 수 있다.

-- 명단 전체를 한 줄에 둔다. rev는 올릴 때마다 1 증가: 오래된 폰이 남의 변경을 덮어쓰지 못하게 앱이 "rev가 그대로일 때만" 고친다.
create table if not exists public.app_state (
  id text primary key,
  data jsonb not null,
  rev integer not null default 1
);

-- 고칠 수 있는 계정 명단: 여기 있는 계정만 app_state를 고친다.
create table if not exists public.editors (
  user_id uuid primary key references auth.users(id) on delete cascade,
  memo text
);

alter table public.app_state enable row level security;
alter table public.editors enable row level security;

-- 앱에서는 자기 줄만 볼 수 있다(아래 권한 확인용). 추가·삭제 정책은 없음 = 대시보드·SQL에서만 관리.
-- 이게 없으면 권한 확인의 select가 0줄이 되어 등록된 계정도 막힌다.
drop policy if exists "본인 등록 확인" on public.editors;
create policy "본인 등록 확인" on public.editors for select to authenticated
  using (user_id = (select auth.uid()));
grant select on public.editors to authenticated;

drop policy if exists "운영진만" on public.app_state;
create policy "운영진만" on public.app_state for all to authenticated
  using (exists (select 1 from public.editors e where e.user_id = (select auth.uid())))
  with check (exists (select 1 from public.editors e where e.user_id = (select auth.uid())));

grant select, insert, update on public.app_state to authenticated;

-- 누구나 보기: 로그인 안 한 사람(anon)도 명단을 읽는다. 읽기만 되고 쓰기 권한은 주지 않는다.
-- 명단(이름·입금·벌칙 기록·회비 계좌)이 인터넷에 공개된다. 다시 막으려면:
--   drop policy "누구나 보기" on public.app_state; revoke select on public.app_state from anon;
drop policy if exists "누구나 보기" on public.app_state;
create policy "누구나 보기" on public.app_state for select to anon, authenticated
  using (true);
grant select on public.app_state to anon;

-- 마스터 등록 (4번에서 만든 계정). 다른 계정을 더 등록하려면 이메일만 바꿔 다시 실행
insert into public.editors (user_id, memo)
select id, email from auth.users where email = 'nasul.master@example.com'
on conflict (user_id) do nothing;
