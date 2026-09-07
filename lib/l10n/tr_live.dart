// live cluster strings. {key: [English, العربية]}. Filled by the translation pass.
const Map<String, List<String>> trLive = {
  // ---- Live match: header / timer -------------------------------------
  'live.appTitle': ['Live Match', 'مباراة مباشرة'],
  'live.live': ['LIVE', 'مباشر'],
  'live.liveTitle': ['Live', 'بث مباشر'],
  // The status pill once the clock runs past its scheduled end — football's
  // stoppage / added time. ⚠️ NOT the same thing as 'live.extraTimeOpt', which is the
  // period a host grants after a level full time. Both read 'وقت إضافي' in
  // Arabic until 2026-09-07, when extra time became a real period and the
  // collision started showing two different states under one word.
  'live.extra': ['ADDED', 'بدل الضائع'],
  'live.halfReadout': ['HALF', 'استراحة'],
  'live.firstHalf': ['1st Half', 'الشوط الأول'],
  'live.secondHalf': ['2nd Half', 'الشوط الثاني'],
  'live.halfTime': ['Half Time', 'الاستراحة'],
  'live.matchFeed': ['Match Feed', 'أحداث المباراة'],

  // ---- Mid-game join approvals ----------------------------------------
  'live.waitingToJoin': ['Waiting to Join', 'بانتظار الانضمام'],
  'live.guest': ['Guest', 'ضيف'],
  'live.approve': ['Approve', 'قبول'],
  'live.decline': ['Decline', 'رفض'],
  'live.added': ['added', 'تمت إضافته'],

  // ---- Feed / actions --------------------------------------------------
  'live.noEvents': [
    'No goals yet — tap a team to log one.',
    'لا أهداف بعد — اضغط على فريق لتسجيل هدف.'
  ],
  'live.ending': ['Ending…', 'جارٍ الإنهاء…'],
  'live.endMatch': ['End Match', 'إنهاء المباراة'],
  'live.goal': ['Goal', 'هدف'],
  'live.viewerNote': [
    'Only the match host can log goals.',
    'يمكن لمضيف المباراة وحده تسجيل الأهداف.'
  ],

  // ---- Half-time banner ------------------------------------------------
  'live.firstHalfComplete': ['First Half Complete', 'انتهى الشوط الأول'],
  'live.halfLocked': [
    'Score and events are locked until the second half.',
    'النتيجة والأحداث مقفلة حتى الشوط الثاني.'
  ],
  'live.halfWaitingHost': [
    'Waiting for the host to start the second half.',
    'في انتظار أن يبدأ المضيف الشوط الثاني.'
  ],
  'live.startSecondHalf': ['Start Second Half', 'ابدأ الشوط الثاني'],

  // ---- Goal / assist sheets --------------------------------------------
  'live.whoScored': ['Who Scored?', 'من سجّل؟'],
  'live.tapScorer': ['tap the scorer.', 'اضغط على المسجّل.'],
  'live.noPlayersTeam': ['No players on this team.', 'لا لاعبين في هذا الفريق.'],
  'live.whoAssisted': ['Who Assisted?', 'من صنع الهدف؟'],
  'live.scoredCredit': [
    'scored. Credit a teammate, or skip.',
    'سجّل. امنح التمريرة الحاسمة لزميل، أو تخطَّ.'
  ],
  'live.noAssist': ['No assist', 'بدون صناعة'],
  'live.assist': ['assist', 'صناعة'],

  // ---- End match confirm ----------------------------------------------
  'live.endMatchQ': ['End Match?', 'إنهاء المباراة؟'],
  'live.endTimeLeft': [
    'There is still time on the clock. End the match now?',
    'لا يزال هناك وقت متبقٍ. هل تريد إنهاء المباراة الآن؟'
  ],
  'live.endConfirm': [
    'Confirm the final result and start the post-match flow.',
    'أكّد النتيجة النهائية وابدأ مرحلة ما بعد المباراة.'
  ],

  // ---- Settings / restart / quit sheets --------------------------------
  'live.matchSettings': ['Match Settings', 'إعدادات المباراة'],
  'live.extendClock': ['Extend Clock', 'تمديد الوقت'],
  'live.min': ['MIN', 'دقيقة'],
  'live.minAdded': ['min added', 'دقيقة أُضيفت'],
  'live.restartMatch': ['Restart Match', 'إعادة المباراة'],
  'live.restartSub': [
    'Wipe every goal and kick off again from 0:00 with the same players.',
    'امسح كل الأهداف وابدأ من جديد من 0:00 بنفس اللاعبين.'
  ],
  'live.restartMatchQ': ['Restart Match?', 'إعادة المباراة؟'],
  'live.restartMsg': [
    'Every logged goal is deleted, the score resets to 0–0 and the clock starts again. The same players keep playing.',
    'تُحذف كل الأهداف المسجّلة وتعود النتيجة إلى 0–0 ويبدأ الوقت من جديد مع بقاء نفس اللاعبين.'
  ],

  // ---- Pause / resume --------------------------------------------------
  'live.paused': ['PAUSED', 'متوقفة'],
  'live.pauseMatch': ['Pause', 'إيقاف مؤقت'],
  'live.matchPaused': ['Match paused', 'المباراة متوقفة'],
  'live.resumeMatch': ['Resume Match', 'استئناف المباراة'],
  'live.pausedBody': [
    'The clock is stopped — the break costs no match time. Resume when play restarts.',
    'الوقت متوقف — لا تُحتسب فترة التوقف من زمن المباراة. استأنف عند عودة اللعب.'
  ],
  'live.pausedWaitingHost': [
    'The host stopped the clock. The match continues when they resume it.',
    'أوقف المضيف الوقت. تستأنف المباراة عندما يعيد تشغيله.'
  ],
  'live.restart': ['Restart', 'إعادة'],
  'live.matchRestarted': ['Match restarted', 'أُعيدت المباراة'],
  'live.quitMatch': ['Quit Match', 'الخروج من المباراة'],
  'live.quitSub': [
    'Something went wrong — abandon or discard.',
    'حدث خطأ ما — اتركها أو تجاهلها.'
  ],
  'live.quitBody': [
    'The game could not be finished. Choose how to close it out.',
    'تعذّر إكمال المباراة. اختر طريقة إنهائها.'
  ],
  'live.saveAbandoned': ['Save as Abandoned', 'حفظ كمتروكة'],
  'live.saveAbandonedSub': [
    'Everything logged is kept. Stats and points count. Marked Abandoned in history.',
    'يُحفظ كل ما سُجّل وتُحتسب الإحصائيات والنقاط وتُوسم كمتروكة في السجل.'
  ],
  'live.saveAbandonedQ': ['Save as Abandoned?', 'حفظ كمتروكة؟'],
  'live.saveAbandonedMsg': [
    'The match is saved as abandoned and stats count towards career totals.',
    'تُحفظ المباراة كمتروكة وتُحتسب الإحصائيات ضمن الإجماليات.'
  ],
  'live.discardEverything': ['Discard Everything', 'تجاهل كل شيء'],
  'live.discardSub': [
    'Delete the match completely. No stats, no points, no record.',
    'احذف المباراة بالكامل. بلا إحصائيات ولا نقاط ولا سجل.'
  ],
  'live.discardMatchQ': ['Discard Match?', 'تجاهل المباراة؟'],
  'live.discardMsg': [
    'This permanently deletes the match and every event. This cannot be undone.',
    'يحذف هذا المباراة وكل أحداثها نهائيًا. لا يمكن التراجع.'
  ],
  'live.discard': ['Discard', 'تجاهل'],

  // ---- Outcome screen --------------------------------------------------
  'live.result': ['Result', 'النتيجة'],
  'live.fullTime': ['Full Time', 'نهاية المباراة'],
  'live.level': ['Level', 'متعادل'],
  'live.howEnded': ['How Did It End?', 'كيف انتهت؟'],
  'live.scoresLevel': ['The Score\'s Level', 'النتيجة متعادلة'],
  'live.extraTimePlayed': [
    'Extra time was played. Record the final outcome — all manual.',
    'لُعب وقت إضافي. سجّل النتيجة النهائية — يدويًا بالكامل.'
  ],
  'live.chooseFinish': [
    'Choose how this match finished.',
    'اختر كيف انتهت هذه المباراة.'
  ],
  'live.endsDraw': ['Ends as a Draw', 'تنتهي بالتعادل'],
  'live.endsDrawSub': [
    'Result recorded as a draw and finalised.',
    'تُسجّل النتيجة كتعادل وتُعتمد.'
  ],
  // Doubles as the outcome option AND the live phase label, so it has to read
  // as a noun. It was 'Extra Time Played' (past tense) while this was a
  // retrospective checkbox; the teams now go back out and play it.
  'live.extraTimeOpt': ['Extra Time', 'وقت إضافي'],
  'live.extraTimeOptSub': [
    'Send them back out — the clock restarts for everyone.',
    'أعدهم إلى الملعب — تُستأنف الساعة للجميع.'
  ],
  'live.stillDraw': ['Still a Draw', 'لا يزال تعادلًا'],
  'live.stillDrawSub': [
    'No winner after extra time.',
    'لا فائز بعد الوقت الإضافي.'
  ],
  'live.penalties': ['Penalties', 'ركلات الترجيح'],
  // Non-hosts are held here while the host settles a level match.
  'live.hostDecidingTitle': [
    'The host is deciding',
    'المضيف يقرّر الآن'
  ],
  'live.hostDecidingSub': [
    'Scores are level. The host is choosing whether this ends as a draw, goes '
        'to extra time, or is settled on penalties. The result appears here as '
        'soon as they decide.',
    'النتيجة متعادلة. يختار المضيف ما إذا كانت ستنتهي بالتعادل أو تذهب إلى وقت '
        'إضافي أو تُحسم بركلات الترجيح. ستظهر النتيجة هنا فور اتخاذ القرار.'
  ],
  // Offered only after the host has been given three minutes and written
  // nothing — see `_hostDecisionGrace`. Worded so it reads as a fallback, not
  // as a normal way out of the wait.
  'live.hostDecidingLeave': [
    'Still waiting — view the result anyway',
    'ما زال الانتظار — اعرض النتيجة على أي حال'
  ],
  // Confirmations on the two irreversible level-game outcomes.
  'live.endsDrawQ': ['End as a draw?', 'إنهاء بالتعادل؟'],
  'live.endsDrawConfirm': [
    'The match is finalised as a draw for both teams. This cannot be changed.',
    'تُعتمد المباراة كتعادل للفريقين. لا يمكن تغيير ذلك.'
  ],
  // Extra time is a real, played period as of 2026-09-07 — the host picks a
  // length and the match goes back out live. The old pair of keys here
  // (`extraTimeQ` / `extraTimeConfirm`) asked "extra time was played?" after
  // the fact and are archived in .claude/l10n_removed_keys.md.
  'live.extraTimeHowLong': ['How long?', 'كم المدة؟'],
  'live.extraTimeHowLongSub': [
    'The clock restarts and the match goes back live for everyone.',
    'تُستأنف الساعة وتعود المباراة مباشرة للجميع.'
  ],
  // Header on the outcome screen the second time round — the score it sits
  // over now includes whatever was scored in extra time.
  'live.afterExtraTime': ['After Extra Time', 'بعد الوقت الإضافي'],
  'live.moreExtraTime': ['Play more extra time', 'وقت إضافي آخر'],
  'live.moreExtraTimeSub': [
    'Still level — send them back out for another period.',
    'ما زال التعادل قائمًا — أعدهم لفترة أخرى.'
  ],
  // Penalty shootout — a top-level way to settle a level match.
  'live.shootoutOpt': ['Penalty Shootout', 'ركلات الترجيح'],
  'live.shootoutOptSub': [
    'Settle it from the spot — pick who scored.',
    'احسمها من علامة الجزاء — اختر من سجّل.'
  ],
  'live.shootoutTitle': ['Shootout score', 'نتيجة ركلات الترجيح'],
  // Replaced `shootoutHint` ("enter how many penalties each team scored"),
  // archived — the sheet no longer takes a number, it takes the scorers, and
  // the score is however many kicks were tapped in.
  'live.shootoutPickHint': [
    'Tap each player who scored. Tap again if they scored more than once.',
    'اضغط على كل لاعب سجّل. اضغط مرة أخرى إذا سجّل أكثر من مرة.'
  ],
  'live.shootoutPickSome': [
    'Pick the players who converted their penalties.',
    'اختر اللاعبين الذين سجّلوا ركلاتهم.'
  ],
  'live.shootoutNoSquad': [
    'No players on this side.',
    'لا يوجد لاعبون في هذا الفريق.'
  ],
  'live.shootoutNoDraw': [
    'A shootout needs a winner — the scores cannot be equal.',
    'ركلات الترجيح تحتاج فائزًا — لا يمكن أن تتساوى النتيجة.'
  ],
  'live.goldenGoal': ['Golden Goal', 'الهدف الذهبي'],
  'live.winOnGolden': ['win on golden goal', 'فاز بالهدف الذهبي'],

  // ---- Public scoreboard ----------------------------------------------
  'live.noMatchSelected': ['No match selected', 'لم تُحدَّد مباراة'],
  'live.openShareLink': [
    'Open a match’s share link to watch it live here.',
    'افتح رابط مشاركة مباراة لمتابعتها مباشرة هنا.'
  ],
  'live.downloadYno': ['Download YNO', 'حمّل YNO'],
  'live.lobby': ['LOBBY', 'الردهة'],
  'live.goals': ['GOALS', 'الأهداف'],
  'live.noGoals': ['No goals yet.', 'لا أهداف بعد.'],
  'live.player': ['PLAYER', 'لاعب'],
  'live.players': ['PLAYERS', 'لاعبين'],

  // ---- Post-match ------------------------------------------------------
  'live.yourMatch': ['Your Match', 'مباراتك'],
  'live.fullScorecard': ['Full Scorecard', 'كشف النتائج الكامل'],
  'live.endedEarly': ['Ended Early', 'انتهت مبكرًا'],
  'live.communityAward': ['Community Award', 'جائزة المجتمع'],
  'live.noCommunityAward': [
    'No Community Award — no votes were cast.',
    'لا جائزة مجتمع — لم يُدلَ بأي صوت.'
  ],
  'live.winner': ['WINNER', 'الفائز'],
  'live.pts': ['PTS', 'نقطة'],
  'live.playersVoting': [
    'Players are voting for the best performer. Closes',
    'يصوّت اللاعبون لأفضل أداء. يُغلق'
  ],
  'live.soon': ['soon', 'قريبًا'],
  'live.inPrefix': ['in', 'خلال'],
  'live.hourShort': ['h', 'س'],
  'live.minShort': ['m', 'د'],
  'live.voteSubmitted': ['Vote submitted.', 'تم إرسال التصويت.'],
  'live.voteWord': ['vote', 'صوت'],
  'live.votesWord': ['votes', 'أصوات'],
  'live.winnerAnnounced': [
    'so far. Winner announced when voting closes',
    'حتى الآن. يُعلن الفائز عند إغلاق التصويت'
  ],
  'live.yourVote': ['Your Vote', 'تصويتك'],
  'live.pickBest': [
    'Pick the best performer. One vote each',
    'اختر أفضل أداء. صوت واحد لكل لاعب'
  ],
  'live.soFar': ['so far', 'حتى الآن'],
  'live.closesWord': ['closes', 'يُغلق'],
  'live.submitting': ['Submitting…', 'جارٍ الإرسال…'],
  'live.castVote': ['Cast Vote', 'صوّت'],
  'live.voteSubmittedToast': ['Vote submitted!', 'تم إرسال التصويت!'],
  'live.voteFailed': ['Could not submit vote.', 'تعذّر إرسال التصويت.'],
  'live.statsSaved': ['Your Stats Are Saved', 'إحصائياتك محفوظة'],
  'live.youScored': ['You scored', 'سجّلت'],
  'live.goalWord': ['goal', 'هدفًا'],
  'live.goalsWord': ['goals', 'أهداف'],
  'live.inThisMatchCreate': [
    'in this match. Create an account to claim your stats and YNO points permanently.',
    'في هذه المباراة. أنشئ حسابًا للاحتفاظ بإحصائياتك ونقاط YNO بشكل دائم.'
  ],
  'live.recordSaved': [
    'Your match record is saved. Create an account to claim your stats and YNO points permanently.',
    'سجل مباراتك محفوظ. أنشئ حسابًا للاحتفاظ بإحصائياتك ونقاط YNO بشكل دائم.'
  ],
  'live.registerNow': ['Register Now', 'سجّل الآن'],
  'live.remindLater': ['Remind Me Later', 'ذكّرني لاحقًا'],
  'live.didNotPlay': [
    'You did not play in this match.',
    'لم تشارك في هذه المباراة.'
  ],
  'live.manOfMatch': ['Man of the Match', 'رجل المباراة'],
  'live.goalsStat': ['Goals', 'الأهداف'],
  'live.assistsStat': ['Assists', 'التمريرات الحاسمة'],
  'live.ynoPoints': ['YNO Points', 'نقاط YNO'],
  'live.shareResult': ['Share Result', 'مشاركة النتيجة'],
  'live.shareFailed': [
    'Could not open share sheet.',
    'تعذّر فتح نافذة المشاركة.'
  ],
  'live.aPlayer': ['A player', 'لاعب'],
  'live.myMatch': ['My match', 'مباراتي'],
  'live.goalsLower': ['goals', 'أهداف'],
  'live.assistsLower': ['assists', 'تمريرات حاسمة'],
  'live.ynoPointsLower': ['YNO points', 'نقاط YNO'],
  'live.motm': ['MOTM', 'رجل المباراة'],
  'live.trackedOnYno': ['Tracked on YNO', 'مُسجّلة على YNO'],
  'live.gaLegend': ['G · A', 'هـ · ص'],
  'live.friends': ['Friends', 'أصدقاء'],
  'live.pending': ['Pending', 'قيد الانتظار'],
  'live.requestSent': ['Friend request sent.', 'تم إرسال طلب الصداقة.'],
  'live.requestFailed': ['Could not send request.', 'تعذّر إرسال الطلب.'],
  'live.notOnYno': [
    'is not yet on YNO — their stats are saved.',
    'ليس على YNO بعد — إحصائياته محفوظة.'
  ],
  'live.adminEditMatch': ['Admin — Edit Match', 'المشرف — تعديل المباراة'],
  'live.editHelp': [
    'Correct or delete goals within 24h of full time. Stats recalculate automatically.',
    'صحّح أو احذف الأهداف خلال 24 ساعة من نهاية المباراة. تُعاد الإحصائيات تلقائيًا.'
  ],
  'live.noGoalsLogged': ['No goals logged.', 'لا أهداف مسجّلة.'],
  'live.assistLabel': ['assist:', 'صناعة:'],
  'live.reassign': ['Reassign', 'إعادة تعيين'],
  'live.goalDeleted': ['Goal deleted.', 'حُذف الهدف.'],
  'live.deleteGoalQ': ['Delete this goal?', 'حذف هذا الهدف؟'],
  'live.deleteGoalBody': [
    'the scoreline and their stats will be updated.',
    'ستُحدَّث النتيجة وإحصائياته.'
  ],
  'live.goalDeleteFailed': ['Could not delete goal.', 'تعذّر حذف الهدف.'],
  'live.reassignScorer': ['Reassign Scorer', 'إعادة تعيين المسجّل'],
  'live.goalReassigned': ['Goal reassigned.', 'أُعيد تعيين الهدف.'],
  'live.reassignFailed': ['Could not reassign goal.', 'تعذّر إعادة تعيين الهدف.'],
};
