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

-- 댓글: 누구나(로그인 없이) 닉네임으로 쓰고 읽는다. 지우기는 마스터(editors)만, 고치기는 아무도 못 한다.
-- room = 명단 id(명단별 댓글) 또는 'guest'(방명록). 이 부분만 따로 실행해도 된다 (다시 실행해도 됨).
-- 공개 키로 누구나 쓸 수 있으므로 도배 방지는 서버가 한다: 글자 수는 check, 1분에 전체 20개까지, 최근 2000개만 남김.
create table if not exists public.comments (
  id bigint generated always as identity primary key,
  room text not null check (char_length(room) between 1 and 40),
  nick text not null check (char_length(btrim(nick)) between 1 and 12),
  body text not null check (char_length(btrim(body)) between 1 and 200),
  is_master boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists comments_room_id on public.comments (room, id desc);
create index if not exists comments_created on public.comments (created_at);
alter table public.comments enable row level security;

-- 쓰기 전에 서버가 정함: 마스터 표시(👑)·시간은 앱이 보낸 값을 무시하고 여기서 넣는다.
-- security definer: 로그인 안 한 사람은 editors를 못 읽으므로 이 함수 권한으로 확인한다.
-- ponytail: 1분 20개는 전체 기준이라 누가 도배하면 그동안 다른 사람도 못 씀. 심해지면 IP별 제한으로 바꿀 것
create or replace function public.comments_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.comments where created_at > now() - interval '1 minute') >= 20 then
    raise exception '댓글이 너무 빨리 올라오고 있어요. 1분 뒤에 다시 써 주세요.';
  end if;
  new.is_master := exists (select 1 from public.editors e where e.user_id = auth.uid());
  new.created_at := now();
  delete from public.comments where id <= (select c.id from public.comments c order by c.id desc offset 1999 limit 1);
  return new;
end $$;
drop trigger if exists comments_before_insert on public.comments;
create trigger comments_before_insert before insert on public.comments
  for each row execute function public.comments_before_insert();

-- Supabase 기본 권한이 anon에게 다 줄 수 있어서 먼저 모두 거두고 필요한 것만 준다
revoke all on public.comments from anon, authenticated;
grant select, insert on public.comments to anon, authenticated;
grant delete on public.comments to authenticated;

drop policy if exists "댓글 누구나 보기" on public.comments;
create policy "댓글 누구나 보기" on public.comments for select to anon, authenticated
  using (true);
drop policy if exists "댓글 누구나 쓰기" on public.comments;
create policy "댓글 누구나 쓰기" on public.comments for insert to anon, authenticated
  with check (true);
drop policy if exists "댓글 마스터만 지우기" on public.comments;
create policy "댓글 마스터만 지우기" on public.comments for delete to authenticated
  using (exists (select 1 from public.editors e where e.user_id = (select auth.uid())));

-- 마스터 등록 (4번에서 만든 계정). 다른 계정을 더 등록하려면 이메일만 바꿔 다시 실행
insert into public.editors (user_id, memo)
select id, email from auth.users where email = 'nasul.master@example.com'
on conflict (user_id) do nothing;
