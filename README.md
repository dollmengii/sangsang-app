# 상상 (가칭)

사진은 흐리게, 첫인상은 태그로. 얼굴은 둘 다 원할 때만 열리는 소개팅 앱입니다.
지금은 친구 15~30명에게만 나눠 주는 **친구용 첫 버전**을 만들고 있습니다. 기획서는 [`docs/plan.md`](docs/plan.md)에 있습니다.

## 구성

| 폴더 | 내용 |
|---|---|
| `app/` | Flutter 안드로이드 앱 (Riverpod, go_router, supabase_flutter, google_sign_in) |
| `supabase/migrations/` | 데이터베이스 표, 보안 규칙(RLS), 크레딧·공개 함수 |
| `supabase/seed.sql` | 태그 초기값 (동물상, 테토·에겐, 무드, 캐릭터상, 취미 등) |
| `supabase/tests/` | 로컬 Postgres로 돌리는 가입·매칭·공개·크레딧 흐름 테스트 |

## 지금 들어 있는 것

- 구글 로그인. 초대 목록(`invites` 표)에 없는 계정은 서버가 가입을 막습니다.
- 가입하면 크레딧 100개를 무료로 줍니다 (`app_config.signup_grant`).
- Gemini 무료 등급 안내와 동의 화면.
- 하단 탭 뼈대 (오늘의 카드, 대화, 나). 카드와 대화 화면은 다음 단계에서 채웁니다.
- 서로 좋아요 → 대화방 자동 생성.
- 얼굴 공개 요청 → 크레딧 보류 → 수락하면 차감, 거절·"조금 더"·48시간 무응답이면 반환. 조건(각자 메시지 10번, 승인된 얼굴 사진, 처리 중인 신고 없음), 대화방당 2번, 24시간 재요청 제한 포함.
- 크레딧 장부는 쌓기만 하고, 클라이언트는 직접 쓸 수 없습니다.

## 처음 설정하기

1. **Supabase 프로젝트** 를 서울 지역(ap-northeast-2)에 만듭니다.
2. SQL Editor에서 `supabase/migrations/20261014000000_foundation.sql`, 그다음 `supabase/seed.sql` 을 실행합니다.
   (Supabase CLI를 쓰면 `supabase link` 뒤 `supabase db push`)
3. 48시간 만료 처리를 켭니다. Database → Extensions에서 `pg_cron` 을 켜고:
   ```sql
   select cron.schedule('expire-reveals', '*/10 * * * *', 'select public.expire_reveal_requests()');
   ```
4. 나를 관리자로 넣고 친구를 초대합니다. 내 계정으로 한 번 로그인한 뒤:
   ```sql
   insert into public.invites (email) values ('내계정@gmail.com');   -- 로그인 전에 먼저
   insert into public.admins (user_id) select id from auth.users where email = '내계정@gmail.com';
   insert into public.invites (email) values ('friend1@gmail.com'), ('friend2@gmail.com');
   ```
5. **구글 로그인**: Google Cloud Console에서 OAuth 클라이언트를 두 개 만듭니다.
   - 웹 클라이언트: 이 ID를 Supabase → Authentication → Providers → Google 에 넣고, 앱의 `GOOGLE_WEB_CLIENT_ID` 로도 씁니다.
   - 안드로이드 클라이언트: 패키지 이름 `com.sangsang.sangsang` 과 디버그·릴리스 키의 SHA-1을 등록합니다.

## 실행

```bash
cd app
flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_... \
  --dart-define=GOOGLE_WEB_CLIENT_ID=xxxx.apps.googleusercontent.com
```

## 테스트

```bash
cd app && flutter analyze && flutter test
PGURL=postgres://postgres:postgres@localhost:5432/postgres supabase/tests/run.sh   # 빈 Postgres 16
```

## 다음 단계

1. 사진 올리기, 위치 정보 제거, 무드 이미지 만들기 (서버 함수)
2. Gemini 태그 분석과 속 에너지 퀴즈, 결과 카드
3. 프로필 입력 화면
4. 오늘의 카드 (밤 10시), 좋아요, 매칭
5. 채팅, 첫 질문 카드, 연락처·돈 이야기 안내
6. 얼굴 공개 화면 (캡처 차단, 60초 주소, 30초 보기)
7. 사진과 달라요, 신고, 차단, 관리자 화면
