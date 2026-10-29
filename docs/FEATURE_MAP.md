# Regular-user web → native feature map

Source reviewed: `/Users/edmondmbadu/repo/living-wiki`. Admin routes, platform analytics, user administration, board factories, maintenance pages, and avatar QA administration are excluded.

| User journey | Native implementation | Existing source / connection |
| --- | --- | --- |
| Explore / all cities / discovery | Editorial home; searchable directory; city, university, topic, person and organization filters; pagination; map; real wiki landing pages | `app.routes.ts`, `atlas.service.ts`; `atlases` where `is_public == true` |
| Public board feed | Bounded summary queries, incremental pages, search, property and tour views | `public_board_summaries`, root/public constraints; `public-board-summary.ts` |
| Personal boards | Ownership-scoped gallery; device bookmarks; board detail; cards, notes, nested boards, sources, places, shopping links, Spotify, YouTube and videos | `boards/boards.ts`; `boards.owner_user_id`, full-board documents |
| Make / edit a board | Titles, descriptions, cover uploads, cards, drag reordering, audience selection, drafts, deletion with confirmation | Same snake-case owner and timestamps, camel-case presentation fields; focused Studio updates and nonce |
| AI-assisted creation | Describe, URL, pasted source, walking or driving tour; choose size; review/edit before saving | `generateBoardWizardBatch`; generation does not automatically publish |
| Shared public collections | Create collections of up to 50 owned public boards, list, read and share | `board-collections.service.ts`; `board_collections` schema |
| Board actions | Share links, device-scoped save, backend likes | `toggleBoardLike`; stable visitor identifier; native share sheet |
| Live / story reading | Swipeable reader, play/pause narration, previous/next; translation and narration language selection | `synthesizeChatAnswerSpeech`, `translateBoard`; web segment translation contract |
| Learning quizzes | Published quiz questions, answer selection, scoring, explanations; signed-in result persistence | `learningQuiz`, `submitBoardQuizAttempt` |
| Walking and driving trips | Tour gallery, card route links and narration | Existing `walking-tour`, `driving-tour`, card tour metadata |
| Songs | Hydrates full boards before identifying songs using structured card metadata; Spotify handoff, audio previews in the reader | `music-board-playlist.ts`; `audioPreviewUrl`, Spotify fields and song tags |
| Video library | Existing videos and generated films, native playback/scrubbing | `users/{uid}/videos`; `video-library.models.ts` |
| Wiki overview / articles / topics | Landing, knowledge tabs, readable Markdown, source document links, topic claims | `getPublicWikiContent`, `getPublicWikiTopicDetails`, `getWikiTopicDetails`, private owner queries |
| Personal wikis | List, membership-enforced creation, knowledge and source library | `atlases`, `wiki_articles`, `wiki_topics`; original personal-wiki entitlement rules |
| Source library | Public and personal documents; upload progress; URL ingestion; source opening | `getPublicAtlasDocuments`, `prepareDocumentUpload`, `submitUrlDocument`, `getWikiSourceDocumentLink` |
| Wiki chat | Wiki/internet modes, public guest limits, explicit wiki selection, citations, knowledge gaps, map links, new conversation | `askPublicAtlas`, `askAtlas`; `chat.service.ts` |
| Conversation history | Ownership-scoped history and stored messages; restore explicit wiki context | `chat_threads`, `chat_messages`; same user/thread/order constraints |
| Wiki voice | Native microphone conversation, language selection, mute, end, transcript and copy | `createElevenLabsVoiceSession` with `connectionType: webrtc`; official `elevenlabs_agents` SDK |
| Talking cards | Native voice session bound to the actual board/card and conversation atlas | `boards/talking-card.ts`; backend visitor access and identity context |
| Off Grids | Public/mine/saved, search, maps and detail, directions, create/edit with confirmed map pin and cover photo | `offGridDirectory`, `offGridCommand` |
| PinTalks | Existing clip playback and contributor-authorized video uploads, captions and progress | `beginUpload`, resumable upload, `finishUpload`, approval enforced by backend |
| Saved gems | Account-backed saves | `users/{uid}/saved_off_grid_spots` |
| Friends | Existing friends, incoming request accept/decline, invitation by email | `listBoardFriends`, `inviteBoardFriend`, `respondBoardFriendRequest` |
| Teams for members | Memberships, workspace listings, members, accept/decline invitations, updates, read state | `teamCommand`, `team_memberships`, `team_notifications` |
| Account | Email sign-in/create, Google sign-in, Apple provider path, recovery, verification, profile/name/photo, sign-out and account deletion | Firebase Auth; existing account-email functions; `users` profile fields |
| Appearance / accessibility | Light and evening themes; scalable text, semantic controls; tested compact, phone and tablet layouts | `core/theme.dart`, widget regression tests |
| Deep links | Custom `livingwiki://boards/id`, `livingwiki://off-grids/id`, wiki/chat links; safe domain handling | `app_links`; HTTPS association remains a distribution task |

## Explicit website continuations

Membership and billing, advanced board film production, avatar/voice configuration, collaborative draft authoring and publishing, and the Trove game use the existing website. They are not disguised as native implementations. Store purchase flows, OS push notifications, complete UI localization and universal-link association deployment require further release work. No native admin surface exists.

## Backend mapping decisions

There are **two** Firestore databases in the Firebase project: `default` (Enterprise) and `(default)` (Standard). The web client initializes Firestore without a database ID and therefore targets **`(default)`**. The mobile client deliberately follows that connection.

Public browsing uses client SDKs and the deployed security rules. Backend functions handle public wiki access, chat limits, narration, translation, friendship changes, team membership and media grants. Client code does not replace these with direct privileged writes.

New boards use `unlisted` as the default audience, visibly labeled “Anyone with the link.” Creating a public board is an explicit choice. The private choice follows the web app's current plan/status pairs. Drafts saved on the device remain on that device.

Auth/profile updates never contain `role`, subscription status, pricing plan or administrative permissions. Account changes clear private routes and restore the correct account-specific bookmarks.
