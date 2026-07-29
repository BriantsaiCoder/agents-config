# Vertical-Slice Tracer Bullet TDD

延伸 `superpowers:test-driven-development` 的 RED-GREEN-REFACTOR,加上 vertical-slice 紀律。

## Anti-Pattern: Horizontal Slices

**DO NOT** 一次寫完所有 test 再一次寫完所有 implementation。Horizontal slicing(把 RED 當「全部 test」、GREEN 當「全部 code」)會生出 crap tests:

- 量產的 test 測的是「想像中」的行為,不是真實行為
- 變成 test「形狀」(資料結構、function signature)而非 user-facing behavior
- Test 對真實變更不敏感:行為壞了還 pass,行為對了反而 fail
- 在還不懂 implementation 之前就把 test 結構鎖死,等於 outrunning your headlights

```
WRONG (horizontal):
  RED:   test1, test2, test3, test4, test5
  GREEN: impl1, impl2, impl3, impl4, impl5

RIGHT (vertical):
  RED→GREEN: test1→impl1
  RED→GREEN: test2→impl2
  RED→GREEN: test3→impl3
```

每個 test 都回應前一輪學到的事。剛寫完 code 你就最清楚什麼行為重要、怎麼驗。

## Workflow

### 1. Planning

下手前:

- [ ] 跟 user 確認 interface 變更
- [ ] 跟 user 確認要 test 哪些 behavior(排優先序)
- [ ] 找 [deep modules](../deep-modules.md) 機會(小 interface、深 implementation)
- [ ] 設計適合 [test 的 interface](../interface-design.md)
- [ ] 列要 test 的 behavior(不是 implementation 步驟)
- [ ] 拿 user approval

問:「public interface 該長怎樣?哪些 behavior 最重要?」

**測不完所有東西。** 跟 user 確認哪些 behavior 真的重要,把 test 火力對準 critical path 跟複雜邏輯,不要每個 edge case 都測。

### 2. Tracer Bullet

寫 ONE test 確認 ONE thing:

```
RED:   寫第一個 behavior 的 test → fail
GREEN: 最少 code 讓它 pass → pass
```

這顆是 tracer bullet — 證明 path end-to-end 通了。

### 3. Incremental Loop

剩下每個 behavior:

```
RED:   寫下一個 test → fail
GREEN: 最少 code → pass
```

規則:

- 一次一 test
- 只寫剛好讓 current test 過的 code
- 不預測下一個 test
- 焦點放 observable behavior

### 4. Refactor

全綠後找 [refactor](../refactoring.md) 機會:

- [ ] 抽 duplication
- [ ] Deepen modules(把複雜度藏到簡單 interface 後面)
- [ ] 自然能套 SOLID 就套
- [ ] 想想新 code 揭露了既有 code 的什麼問題
- [ ] 每步 refactor 後都跑 test

**RED 時不准 refactor。** 先 GREEN。

## Per-Cycle Checklist

```
[ ] Test 描述 behavior,不是 implementation
[ ] Test 只用 public interface
[ ] Test 撐得過 internal refactor
[ ] Code 對這顆 test 而言是 minimal
[ ] 沒加投機性的 feature
```

## 相關檔

- [deep-modules.md](../deep-modules.md) — 深模組設計
- [interface-design.md](../interface-design.md) — testability-first 介面
- [mocking.md](../mocking.md) — mock 規範
- [refactoring.md](../refactoring.md) — refactor 候選
- [tests.md](../tests.md) — 好/壞 test 範例
