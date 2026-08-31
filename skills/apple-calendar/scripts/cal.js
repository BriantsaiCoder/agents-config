ObjC.import('EventKit')
ObjC.import('Foundation')

// ---------- 基礎工具 ----------

// 固定 en_US_POSIX，避免使用者 locale (zh-TW) 影響日期格式化。
// formatter 建構是熱點（實測 158us/次），而全程只用三種 pattern，故快取。
const FMT_CACHE = {}
function fmt(dt, pattern) {
  let df = FMT_CACHE[pattern]
  if (df === undefined) {
    df = $.NSDateFormatter.alloc.init
    df.locale = $.NSLocale.alloc.initWithLocaleIdentifier('en_US_POSIX')
    df.dateFormat = pattern
    FMT_CACHE[pattern] = df
  }
  return ObjC.unwrap(df.stringFromDate(dt))
}

function posInt(v, what, dflt) {
  if (v === undefined) return dflt
  if (!/^\d+$/.test(v) || parseInt(v, 10) < 1) throw new Error(what + ' 需為正整數，收到: ' + v)
  return parseInt(v, 10)
}

function mkdate(y, mo, d, h, mi) {
  const c = $.NSDateComponents.alloc.init
  c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi; c.second = 0
  const dt = $.NSCalendar.currentCalendar.dateFromComponents(c)
  if (dt.isNil()) throw new Error('無法建構日期: ' + [y, mo, d, h, mi].join('/'))
  return dt
}

// 解析 ISO，並回查確認未被 normalize（例如 2026-02-30 會被靜默推成 3/2）
function parseISO(s, what) {
  const m = /^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2}))?$/.exec(s)
  if (!m) throw new Error(what + ' 格式錯誤: "' + s + '"（需 YYYY-MM-DD 或 YYYY-MM-DDTHH:MM）')
  const dt = mkdate(+m[1], +m[2], +m[3], m[4] ? +m[4] : 0, m[5] ? +m[5] : 0)
  if (fmt(dt, 'yyyy-MM-dd') !== m[1] + '-' + m[2] + '-' + m[3]) {
    throw new Error(what + ' 不是有效日期: "' + s + '"')
  }
  return dt
}

function today0() {
  return $.NSCalendar.currentCalendar.startOfDayForDate($.NSDate.date)
}

// ---------- 授權閘 ----------
// writeOnly (4) 讀查詢會靜默回空集合而非報錯 —— 呼叫端會誤判「當天沒事」。
// 因此非 fullAccess (3) 一律硬失敗。TCC 授權掛在 responsible process（呼叫的 AI host）上，
// 換一個 host 就要重新授權。
function requireFullAccess() {
  const st = $.EKEventStore.authorizationStatusForEntityType($.EKEntityTypeEvent)
  if (Number(st) === 3) return
  const names = { 0: 'notDetermined 尚未決定', 1: 'restricted 受限', 2: 'denied 已拒絕', 4: 'writeOnly 僅可寫入' }
  // status=0 在沙箱內是常態：同一台機器、同一個 host，沙箱外回 3、沙箱內回 0。
  // 不區分的話錯誤訊息會把已授權的使用者導去系統設定，改完症狀不變，形成誤診迴圈。
  const hint = Number(st) === 0
    ? '  這個 host 若先前成功用過本工具，status=0 通常是沙箱攔截而非未授權 —— 先以停用沙箱重跑。\n'
    : ''
  throw new Error(
    '行事曆權限不足: status=' + st + ' (' + (names[st] || '未知') + ')，需要 fullAccess(3)。\n' +
    '  writeOnly 會讓查詢靜默回傳空結果，因此拒絕繼續。\n' +
    hint +
    '  仍不行才是真的未授權: 系統設定 → 隱私權與安全性 → 行事曆 → 開啟呼叫端 app 的完整存取權。')
}

function store() { return $.EKEventStore.alloc.init }

function authorizationWaitPending(before, current, done, granted) {
  return current === before && (!done || granted)
}

function cmdAuthorize(argv) {
  parseFlags(argv, 1, 'authorize')
  const before = Number($.EKEventStore.authorizationStatusForEntityType($.EKEntityTypeEvent))
  if (before === 3) return '行事曆已取得 fullAccess(3)'
  if (before === 1) {
    throw new Error('macOS 系統政策限制行事曆權限；請解除家長監護／MDM 限制或聯絡管理員')
  }
  if (before === 2) {
    throw new Error('macOS 已拒絕行事曆權限；請到「系統設定 → 隱私權與安全性 → 行事曆」開啟完整存取權')
  }

  const st = store()
  const supportsFull = st.respondsToSelector('requestFullAccessToEventsWithCompletion:')
  const supportsLegacy = st.respondsToSelector('requestAccessToEntityType:completion:')
  if (!supportsFull && !supportsLegacy) {
    throw new Error('此 macOS 版本不支援 EventKit 行事曆授權 API')
  }

  let done = false, granted = false, message = ''
  const completion = ObjC.block('void', ['bool', 'id'], function (ok, error) {
    granted = Boolean(ok)
    try { if (error && !error.isNil()) message = ObjC.unwrap(error.localizedDescription) }
    catch (e) { message = 'EventKit 錯誤訊息無法解析' }
    if (!granted && !message) message = '使用者未允許行事曆存取'
    done = true
  })
  if (supportsFull) st.requestFullAccessToEventsWithCompletion(completion)
  else st.requestAccessToEntityTypeCompletion($.EKEntityTypeEvent, completion)

  // JXA completion 可能不回到主執行緒；TCC status 會先更新，任一完成即可。
  const deadline = $.NSDate.dateWithTimeIntervalSinceNow(120)
  while (authorizationWaitPending(
           before, Number($.EKEventStore.authorizationStatusForEntityType($.EKEntityTypeEvent)), done, granted) &&
         deadline.timeIntervalSinceNow > 0) {
    $.NSRunLoop.currentRunLoop.runUntilDate($.NSDate.dateWithTimeIntervalSinceNow(0.1))
  }

  const after = Number($.EKEventStore.authorizationStatusForEntityType($.EKEntityTypeEvent))
  if (after === 3) return '行事曆授權成功: fullAccess(3)'
  if (after === before && (!done || granted)) throw new Error('等候 macOS 行事曆授權逾時，請重新執行 calx authorize')
  throw new Error('未取得行事曆完整存取權: status=' + after + (message ? '，' + message : ''))
}

function calendars(st) {
  return ObjC.unwrap(st.calendarsForEntityType($.EKEntityTypeEvent))
}

function findCalendar(st, name) {
  const cals = calendars(st)
  const hit = cals.find(function (c) { return ObjC.unwrap(c.title) === name })
  if (hit) return hit
  const avail = cals.filter(function (c) { return c.allowsContentModifications })
                    .map(function (c) { return ObjC.unwrap(c.title) })
  throw new Error('找不到行事曆「' + name + '」。可寫入的有: ' + avail.join(', '))
}

// NSError out-param 必須用 $() + isNil() 讀，ObjC.castRefToObject 會 segfault。
// save 與 remove 共用這一份，避免陷阱處理出現兩份會漂移的副本。
function ekOrThrow(what, call) {
  const err = $()
  if (call(err)) return
  let msg = '(無錯誤訊息)'
  try { if (!err.isNil()) msg = ObjC.unwrap(err.localizedDescription) } catch (e) {}
  throw new Error(what + '失敗: ' + msg)
}

function describe(e) {
  const allday = e.isAllDay
  let when
  if (allday) {
    const sd = fmt(e.startDate, 'yyyy-MM-dd'), ed = fmt(e.endDate, 'yyyy-MM-dd')
    when = (sd === ed ? sd : sd + '~' + ed) + ' 全天'
  } else {
    when = fmt(e.startDate, 'yyyy-MM-dd HH:mm') + '-' + fmt(e.endDate, 'HH:mm')
  }
  const loc = ObjC.unwrap(e.location) || ''
  const tags = []
  if (e.hasRecurrenceRules) tags.push(recurrenceLabel(e))
  return [
    when,
    ObjC.unwrap(e.title) || '(無標題)',
    ObjC.unwrap(e.calendar.title),
    loc,
    tags.join(','),
    'id=' + ObjC.unwrap(e.eventIdentifier)
  ].join(' | ')
}

// 重複事件的每一場次共用同一個 eventIdentifier，eventWithIdentifier 只會回傳「第一場」。
// 因此重複事件一律要求 --on YYYY-MM-DD 指定場次，否則會靜默改錯場次。
// 已被單獨修改過的場次（detached occurrence）id 會多出 "/RID=…" 後綴，比對時取基礎段。
function baseId(s) {
  const i = s.indexOf('/RID=')
  return i < 0 ? s : s.slice(0, i)
}

// 回傳 event 或 null。刪除確認需要「存在與否」這個述詞——用 try/catch 當布林會把
// store 錯誤、predicate 失敗一併吞成「已刪除」，而那是最不該假綠的地方。
function findEvent(st, id, onDate) {
  if (onDate === undefined) {
    const ev = st.eventWithIdentifier(id)
    return ev.isNil() ? null : ev
  }
  const day = parseISO(onDate, '--on')
  const evs = ObjC.unwrap(st.eventsMatchingPredicate(
    st.predicateForEventsWithStartDateEndDateCalendars(day, day.dateByAddingTimeInterval(24 * 3600), $())))
  const want = baseId(id)
  const hit = evs.find(function (e) { return baseId(ObjC.unwrap(e.eventIdentifier)) === want })
  return hit === undefined ? null : hit
}

function getEvent(st, id, onDate) {
  const ev = findEvent(st, id, onDate)
  if (ev === null) {
    throw new Error(onDate === undefined
      ? '找不到事件 id=' + id + '（可能已刪除，或 id 來自另一台機器）'
      : '在 ' + onDate + ' 找不到 id=' + id + ' 的場次')
  }
  if (onDate === undefined && ev.hasRecurrenceRules) {
    throw new Error(
      '這是重複事件，所有場次共用同一個 id，未指定場次會動到第一場（' +
      fmt(ev.startDate, 'yyyy-MM-dd') + '）。\n' +
      '  請加 --on YYYY-MM-DD 指定要操作哪一場。')
  }
  return ev
}

function parseSpan(v) {
  if (v === undefined || v === 'this') return $.EKSpanThisEvent
  if (v === 'future') return $.EKSpanFutureEvents
  throw new Error('--span 只接受 this 或 future，收到: ' + v)
}

// ---------- 重複規則 ----------
// EKRecurrenceFrequency: daily=0 weekly=1 monthly=2 yearly=3
const FREQ = { daily: 0, weekly: 1, monthly: 2, yearly: 3 }
const FREQ_UNIT = ['日', '週', '月', '年']

// 只驗證參數、不建立 ObjC 物件，便於在 selftest 中測試而不碰行事曆
function validateRecurrence(flags) {
  if (flags.repeat === undefined) {
    for (const k of ['count', 'until', 'interval']) {
      if (flags[k] !== undefined) throw new Error('--' + k + ' 需搭配 --repeat 使用')
    }
    return null
  }
  const freq = FREQ[flags.repeat]
  if (freq === undefined) {
    throw new Error('--repeat 只接受 daily／weekly／monthly／yearly，收到: ' + flags.repeat)
  }
  const interval = posInt(flags.interval, '--interval', 1)
  if (flags.count !== undefined && flags.until !== undefined) {
    throw new Error('--count 與 --until 只能擇一')
  }
  const count = posInt(flags.count, '--count', null)
  if (flags.until !== undefined) parseISO(flags.until, '--until')  // 格式錯要在寫入前就擋下
  return { freq: freq, interval: interval, count: count, until: flags.until }
}

function buildRecurrence(spec, startDate) {
  let end = $()
  if (spec.count !== null) {
    end = $.EKRecurrenceEnd.recurrenceEndWithOccurrenceCount(spec.count)
  } else if (spec.until !== undefined) {
    // 取當日 23:59:59 —— 只給純日期時 parseISO 回 00:00，會把當天的場次排除在外
    const u = parseISO(spec.until, '--until').dateByAddingTimeInterval(23 * 3600 + 59 * 60 + 59)
    if (u.timeIntervalSinceDate(startDate) <= 0) throw new Error('--until 不得早於開始時間')
    end = $.EKRecurrenceEnd.recurrenceEndWithEndDate(u)
  }
  return $.EKRecurrenceRule.alloc.initRecurrenceWithFrequencyIntervalEnd(spec.freq, spec.interval, end)
}

function recurrenceLabel(e) {
  const rules = e.recurrenceRules
  if (rules.isNil() || rules.count === 0) return '重複'
  const r = rules.objectAtIndex(0)
  const unit = FREQ_UNIT[Number(r.frequency)]   // Calendar.app 可建出這四種以外的頻率
  const iv = Number(r.interval)
  if (unit === undefined) return '重複' + (iv > 1 ? ':每' + iv + '次' : '')
  return '重複:每' + (iv > 1 ? iv : '') + unit
}

// ---------- 參數解析 ----------
// 每個子命令的合法旗標與位置參數上限。未知旗標必須擋下而非忽略：
// 沒有白名單時 `--allDay`（大小寫寫錯）會被當成具值旗標，吃掉後面的 `--cal`，
// 結果是「非全天 + 寫進預設行事曆 + 零警告」——正是這個工具要防的那種靜默失敗。
const SPEC = {
  authorize: { flags: [], bool: [], pos: 0 },
  list:      { flags: ['from', 'days', 'cal'], bool: [], pos: 0 },
  add:       { flags: ['cal', 'loc', 'allday', 'repeat', 'interval', 'count', 'until'], bool: ['allday'], pos: 3 },
  edit:      { flags: ['title', 'start', 'end', 'loc', 'cal', 'on', 'span'], bool: [], pos: 1 },
  delete:    { flags: ['on', 'span'], bool: [], pos: 1 },
  calendars: { flags: [], bool: [], pos: 0 },
  selftest:  { flags: [], bool: [], pos: 0 }
}

function parseFlags(argv, from, cmd) {
  const spec = SPEC[cmd]
  if (spec === undefined) throw new Error('內部錯誤: 未定義子命令 "' + cmd + '" 的參數規格')
  const pos = [], flags = {}
  for (let i = from; i < argv.length; i++) {
    const a = argv[i]
    if (a.indexOf('--') === 0) {
      const k = a.slice(2)
      if (spec.flags.indexOf(k) < 0) {
        throw new Error('未知旗標 --' + k + '（' + cmd + ' 可用: ' +
          (spec.flags.length ? spec.flags.map(function (f) { return '--' + f }).join(' ') : '無') + '）')
      }
      if (spec.bool.indexOf(k) >= 0) { flags[k] = true; continue }
      i++
      if (i >= argv.length) throw new Error('--' + k + ' 缺少值')
      flags[k] = argv[i]
    } else pos.push(a)
  }
  if (pos.length > spec.pos) {
    throw new Error(cmd + ' 只接受 ' + spec.pos + ' 個位置參數，收到 ' + pos.length +
      ' 個: ' + pos.map(function (p) { return '"' + p + '"' }).join(' ') +
      (spec.pos > 0 ? '（含空白的參數要用引號包起來）' : ''))
  }
  return { pos: pos, flags: flags }
}

// ---------- 子命令 ----------

function cmdCalendars(argv) {
  parseFlags(argv, 1, 'calendars')
  requireFullAccess()
  const st = store()
  const types = { 0: 'local本機', 1: 'exchange', 2: 'calDAV', 3: 'mobileMe', 4: '訂閱', 5: 'birthdays' }
  return calendars(st).map(function (c) {
    return [
      ObjC.unwrap(c.title),
      c.allowsContentModifications ? '可寫' : '唯讀',
      ObjC.unwrap(c.source.title) + '/' + (types[c.source.sourceType] || c.source.sourceType)
    ].join(' | ')
  }).sort().join('\n')
}

function cmdList(argv) {
  const { flags } = parseFlags(argv, 1, 'list')
  const from = flags.from ? parseISO(flags.from, '--from') : today0()
  const days = posInt(flags.days, '--days', 7)
  requireFullAccess()
  const st = store()
  const to = from.dateByAddingTimeInterval(days * 24 * 3600)

  let cals = $()
  if (flags.cal) cals = $([findCalendar(st, flags.cal)])

  const evs = ObjC.unwrap(st.eventsMatchingPredicate(
    st.predicateForEventsWithStartDateEndDateCalendars(from, to, cals)))

  const head = fmt(from, 'yyyy-MM-dd') + ' 起 ' + days + ' 天'
    + (flags.cal ? '（行事曆: ' + flags.cal + '）' : '（全部行事曆）')
    + '，共 ' + evs.length + ' 筆'
  if (evs.length === 0) return head
  return head + '\n' + evs.map(describe).join('\n')
}

function cmdAdd(argv) {
  const { pos, flags } = parseFlags(argv, 1, 'add')
  if (pos.length < 3) {
    throw new Error('用法: calx add <開始> <結束或分鐘數> <標題> [--cal 行事曆] [--loc 地點] [--allday]\n      [--repeat daily|weekly|monthly|yearly] [--interval N] [--count N | --until YYYY-MM-DD]')
  }
  // 所有格式驗證排在授權檢查與 store 建立之前：便宜的檢查先跑，
  // 參數打錯時不必先付 store 冷啟動（實測 33ms），沙箱內也驗得到。
  const recSpec = validateRecurrence(flags)
  const start = parseISO(pos[0], '開始時間')
  let end
  if (flags.allday) {
    // 全天事件：第二參數是結束「日期」；取當日 23:59 收尾，避免被算成多一天
    if (/^\d+$/.test(pos[1])) {
      throw new Error('--allday 時第二參數需為結束日期（YYYY-MM-DD），不接受分鐘數')
    }
    end = parseISO(pos[1], '結束日期').dateByAddingTimeInterval(23 * 3600 + 59 * 60)
    if (end.timeIntervalSinceDate(start) <= 0) throw new Error('結束日期不得早於開始日期')
  } else {
    if (/^\d+$/.test(pos[1])) end = start.dateByAddingTimeInterval(parseInt(pos[1], 10) * 60)
    else end = parseISO(pos[1], '結束時間')
    if (end.timeIntervalSinceDate(start) <= 0) throw new Error('結束時間不得早於或等於開始時間')
  }

  requireFullAccess()
  const st = store()
  const calName = flags.cal || '工作'
  const cal = findCalendar(st, calName)
  if (!cal.allowsContentModifications) {
    throw new Error('行事曆「' + calName + '」為唯讀（訂閱或系統行事曆），無法新增')
  }

  const ev = $.EKEvent.eventWithEventStore(st)
  ev.title = pos[2]
  ev.startDate = start
  ev.endDate = end
  ev.calendar = cal
  if (flags.loc) ev.location = flags.loc
  // 注意: setter 是 allDay，isAllDay 只是 getter —— 寫 ev.isAllDay 會靜默不生效
  if (flags.allday) ev.allDay = true
  if (recSpec) ev.recurrenceRules = $([buildRecurrence(recSpec, start)])

  // 建立重複事件要用 EKSpanFutureEvents，否則規則不會套用到整個系列
  ekOrThrow('新增', function (e) {
    return st.saveEventSpanError(ev, recSpec ? $.EKSpanFutureEvents : $.EKSpanThisEvent, e)
  })

  // 回讀驗證：不以 save 回 true 當作已寫入
  const back = store().eventWithIdentifier(ev.eventIdentifier)
  if (back.isNil()) throw new Error('新增後回讀不到事件，未確認寫入')
  if (recSpec && !back.hasRecurrenceRules) {
    throw new Error('事件已建立，但重複規則未寫入（回讀時 hasRecurrenceRules 為 false）')
  }
  return '已新增\n' + describe(back)
}

function cmdEdit(argv) {
  const { pos, flags } = parseFlags(argv, 1, 'edit')
  requireFullAccess()
  if (pos.length < 1) {
    throw new Error('用法: calx edit <id> [--title T] [--start ISO] [--end ISO] [--loc L] [--cal 行事曆] [--on YYYY-MM-DD] [--span this|future]')
  }
  const st = store()
  const ev = getEvent(st, pos[0], flags.on)
  const before = describe(ev)

  if (!ev.calendar.allowsContentModifications) {
    throw new Error('事件所在行事曆「' + ObjC.unwrap(ev.calendar.title) + '」為唯讀，無法修改')
  }
  const span = parseSpan(flags.span)
  if (ev.hasRecurrenceRules && flags.span === undefined) {
    console.log('提醒: 這是重複事件，預設只改本次場次（--span future 可改本次及之後所有場次）')
  }

  let changed = 0
  if (flags.title !== undefined) { ev.title = flags.title; changed++ }
  if (flags.loc !== undefined) { ev.location = flags.loc; changed++ }
  if (flags.cal !== undefined) {
    const target = findCalendar(st, flags.cal)
    if (!target.allowsContentModifications) {
      throw new Error('目標行事曆「' + flags.cal + '」為唯讀，無法搬移過去')
    }
    ev.calendar = target; changed++
  }
  // start/end 一起設定後才儲存，避免中間狀態 end<start 被拒
  if (flags.start !== undefined) { ev.startDate = parseISO(flags.start, '--start'); changed++ }
  if (flags.end !== undefined) { ev.endDate = parseISO(flags.end, '--end'); changed++ }
  if (changed === 0) throw new Error('未指定任何要修改的欄位')
  if (ev.endDate.timeIntervalSinceDate(ev.startDate) <= 0 && !ev.isAllDay) {
    throw new Error('修改後結束時間不得早於或等於開始時間')
  }

  ekOrThrow('修改', function (e) { return st.saveEventSpanError(ev, span, e) })

  // 這裡刻意用 ev.eventIdentifier 而非 getEvent(..., flags.on) 重查，兩種 span 都對，別「修正」成後者：
  //   span=this  → 該場次 detach，ev.eventIdentifier 變成帶 /RID= 的專屬 id，取回的就是那一場。
  //   span=future → EventKit 分裂系列並給 ev 一個新的 identifier，指向分裂後的新系列，
  //                 而新系列的第一場正好是 --on 指定的那場。
  // 2026-08-31 實測（5 場每日系列，--on 第 3 場 --span future）：回讀報 3/3，
  // 獨立查詢確認 3/1–3/2 未變、3/3–3/5 已改。
  const back = store().eventWithIdentifier(ev.eventIdentifier)
  if (back.isNil()) throw new Error('修改後回讀不到事件')
  return '已修改\n  修改前: ' + before + '\n  修改後: ' + describe(back)
}

function cmdDelete(argv) {
  const { pos, flags } = parseFlags(argv, 1, 'delete')
  requireFullAccess()
  if (pos.length < 1) throw new Error('用法: calx delete <id> [--on YYYY-MM-DD] [--span this|future]')
  const st = store()
  const ev = getEvent(st, pos[0], flags.on)
  const desc = describe(ev)
  if (!ev.calendar.allowsContentModifications) {
    throw new Error('事件所在行事曆「' + ObjC.unwrap(ev.calendar.title) + '」為唯讀，無法刪除')
  }
  const span = parseSpan(flags.span)
  if (ev.hasRecurrenceRules && flags.span === undefined) {
    console.log('提醒: 這是重複事件，預設只刪本次場次（--span future 可刪本次及之後所有場次）')
  }
  ekOrThrow('刪除', function (e) { return st.removeEventSpanError(ev, span, e) })
  // 回讀驗證刪除確實生效。
  // 重複事件刪掉某一場後系列本身仍在，eventWithIdentifier 依然回傳非 nil，
  // 因此指定了場次時要改查「那一天還有沒有這個事件」，否則會誤判成刪除失敗。
  if (findEvent(store(), pos[0], flags.on) !== null) {
    throw new Error('刪除指令回報成功，但事件仍可讀取，未確認刪除')
  }
  return '已刪除\n  ' + desc
}

function cmdSelftest(argv) {
  parseFlags(argv, 1, 'selftest')
  const results = []
  let rc = 0
  function ck(name, got, want) {
    if (got === want) results.push('ok   ' + name + ' -> ' + got)
    else { results.push('FAIL ' + name + ' 得到 "' + got + '" 預期 "' + want + '"'); rc = 1 }
  }
  function throws(name, fn) {
    try { fn(); results.push('FAIL ' + name + ' 應拋錯但沒有'); rc = 1 }
    catch (e) { results.push('ok   ' + name + ' 正確拒絕') }
  }
  ck('parseISO 日期時間', fmt(parseISO('2026-09-01T15:30', 't'), 'yyyy-MM-dd HH:mm'), '2026-09-01 15:30')
  ck('parseISO 空白分隔', fmt(parseISO('2026-09-01 15:30', 't'), 'yyyy-MM-dd HH:mm'), '2026-09-01 15:30')
  ck('parseISO 純日期', fmt(parseISO('2026-09-01', 't'), 'yyyy-MM-dd HH:mm'), '2026-09-01 00:00')
  ck('parseISO 跨年末', fmt(parseISO('2026-12-31T23:59', 't'), 'yyyy-MM-dd HH:mm'), '2026-12-31 23:59')
  ck('parseISO 短月份邊界', fmt(parseISO('2026-02-28', 't'), 'yyyy-MM-dd'), '2026-02-28')
  throws('parseISO 拒絕 2026-02-30 (不得靜默推成 3/2)', function () { parseISO('2026-02-30', 't') })
  throws('parseISO 拒絕 2026/09/01', function () { parseISO('2026/09/01', 't') })
  throws('parseISO 拒絕 26-09-01', function () { parseISO('26-09-01', 't') })
  throws('parseISO 拒絕含秒', function () { parseISO('2026-09-01T15:00:00', 't') })
  throws('parseSpan 拒絕未知值', function () { parseSpan('all') })
  ck('parseSpan 預設 this', String(parseSpan(undefined) === $.EKSpanThisEvent), 'true')
  ck('parseSpan future', String(parseSpan('future') === $.EKSpanFutureEvents), 'true')

  const f = parseFlags(['add', 'A', 'B', 'C', '--cal', 'X', '--allday', '--loc', 'L'], 1, 'add')
  ck('parseFlags 位置參數', f.pos.join(','), 'A,B,C')
  ck('parseFlags 具值旗標', f.flags.cal + '/' + f.flags.loc, 'X/L')
  ck('parseFlags 布林旗標', String(f.flags.allday), 'true')
  throws('parseFlags 旗標缺值', function () { parseFlags(['x', '--cal'], 1, 'add') })
  throws('parseFlags 拒絕未知旗標', function () { parseFlags(['add', '--repaet', 'weekly'], 1, 'add') })
  throws('parseFlags 拒絕大小寫錯的旗標', function () { parseFlags(['add', '--allDay'], 1, 'add') })
  throws('parseFlags 拒絕超量位置參數', function () { parseFlags(['add', 'A', 'B', 'C', 'D'], 1, 'add') })
  throws('parseFlags list 不收位置參數', function () { parseFlags(['list', '2026-09-08'], 1, 'list') })
  throws('parseFlags 白名單不跨子命令', function () { parseFlags(['delete', '--repeat', 'daily'], 1, 'delete') })
  ck('parseFlags edit 接受 --on', String(parseFlags(['edit', 'ID', '--on', '2026-09-21'], 1, 'edit').flags.on), '2026-09-21')
  ck('parseFlags authorize 接受零參數', String(parseFlags(['authorize'], 1, 'authorize').pos.length), '0')
  throws('parseFlags authorize 拒絕多餘參數', function () { parseFlags(['authorize', 'extra'], 1, 'authorize') })
  ck('authorize completion 成功先到仍等待 status', String(authorizationWaitPending(0, 0, true, true)), 'true')

  ck('validateRecurrence 無重複回 null', String(validateRecurrence({}) === null), 'true')
  const rs = validateRecurrence({ repeat: 'weekly', interval: '2', count: '12' })
  ck('validateRecurrence 解析 freq/interval/count', rs.freq + '/' + rs.interval + '/' + rs.count, '1/2/12')
  ck('validateRecurrence 預設 interval', String(validateRecurrence({ repeat: 'daily' }).interval), '1')
  throws('validateRecurrence 拒絕未知頻率', function () { validateRecurrence({ repeat: 'hourly' }) })
  throws('validateRecurrence 拒絕 count 與 until 並用', function () { validateRecurrence({ repeat: 'weekly', count: '3', until: '2026-12-31' }) })
  throws('validateRecurrence 拒絕 interval 為 0', function () { validateRecurrence({ repeat: 'weekly', interval: '0' }) })
  throws('validateRecurrence 拒絕 count 非數字', function () { validateRecurrence({ repeat: 'weekly', count: 'many' }) })
  throws('validateRecurrence 拒絕無 --repeat 卻給 --count', function () { validateRecurrence({ count: '3' }) })
  throws('validateRecurrence 拒絕格式錯的 --until', function () { validateRecurrence({ repeat: 'daily', until: '2026/09/13' }) })
  throws('validateRecurrence 拒絕無效日期的 --until', function () { validateRecurrence({ repeat: 'daily', until: '2026-02-30' }) })
  ck('validateRecurrence 保留 --until', validateRecurrence({ repeat: 'daily', until: '2026-09-13' }).until, '2026-09-13')

  const st = $.EKEventStore.authorizationStatusForEntityType($.EKEntityTypeEvent)
  results.push('info 目前授權 status=' + st + (Number(st) === 3 ? ' (fullAccess)' : ' (非 fullAccess，讀寫子命令會硬失敗)'))
  results.push(rc === 0 ? 'SELFTEST PASS' : 'SELFTEST FAIL')
  if (rc !== 0) throw new Error(results.join('\n'))
  return results.join('\n')
}

const USAGE = [
  'calx — Apple 行事曆 (EventKit) 查詢／新增／修改／刪除',
  '',
  '  calx authorize',
  '  calx list   [--from YYYY-MM-DD] [--days N] [--cal 行事曆]',
  '  calx add    <開始> <結束或分鐘數> <標題> [--cal 行事曆] [--loc 地點] [--allday]',
  '                                          [--repeat daily|weekly|monthly|yearly]',
  '                                          [--interval N] [--count N | --until YYYY-MM-DD]',
  '  calx edit   <id> [--title T] [--start ISO] [--end ISO] [--loc L] [--cal 行事曆] [--on YYYY-MM-DD] [--span this|future]',
  '  calx delete <id> [--on YYYY-MM-DD] [--span this|future]',
  '  calx calendars',
  '  calx selftest',
  '',
  '（cal-list／cal-add／cal-edit／cal-delete 為等價包裝）',
  '',
  '時間格式: YYYY-MM-DD 或 YYYY-MM-DDTHH:MM（不含秒）。id 由 list 輸出。',
  '重複排程: --repeat 設頻率，--interval 設間隔（每 N 週），--count／--until 設結束條件（不給則無限）。',
  '          例: calx add 2026-09-07T10:00 60 "部門週會" --repeat weekly --count 12',
  '重複事件: 所有場次共用同一個 id，edit／delete 必須用 --on 指定場次，否則拒絕執行。',
  '          預設只影響該場次；--span future 才會動到該場次及之後所有場次。'
].join('\n')

function run(argv) {
  const cmd = argv[0]
  switch (cmd) {
    case 'authorize': return cmdAuthorize(argv)
    case 'list': return cmdList(argv)
    case 'add': return cmdAdd(argv)
    case 'edit': return cmdEdit(argv)
    case 'delete': return cmdDelete(argv)
    case 'calendars': return cmdCalendars(argv)
    case 'selftest': return cmdSelftest(argv)
    case undefined:
    case '-h':
    case '--help': return USAGE
    default: throw new Error('未知子命令: ' + cmd + '\n\n' + USAGE)
  }
}
