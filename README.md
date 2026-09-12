# MoonRecur

MoonRecur 是一个 MoonBit 日期级重复日程库及命令行工具。输入起始日期、RRULE
和查询窗口，输出有序发生日期；可加入 RDATE、排除 EXDATE，并对全天占用区间
检查冲突、合并忙时段、查找空闲区间。适合离线提醒、课程排期和预约工具。

它处理的是**公历日期，不是时区中的时刻**：不隐式读取系统时区，不运行定时器，
不解析完整 `.ics` 文件。支持范围见 [RRULE 支持矩阵](docs/SUPPORTED_RRULE.md)。

## 0.2.1 维护内容与质量证据

本次在既有 0.2.0 基础上修复语义和输入校验问题，保持公开库 API 签名不变。

- 修复 YEARLY 月份继承和跨月份选择，避免规则合法却漏掉日期。
- EXDATE 在最终 limit 之前生效，但不改变 COUNT 对原始规则发生次数的计数。
- 拒绝整数溢出、超长规则、无效公开结构体、重复/未知 CLI 参数；未知命令不再成功退出。
- 跳过不活跃周期；例外日期与占用区间改用排序，避免插入排序的增长开销。

| 验证项 | 结果与口径 |
| --- | --- |
| 单元/回归/性质测试 | 66 个测试组 |
| python-dateutil 2.9.0.post0 对照 | 同一组 800 例，旧提交 692 通过/108 失败；维护后全部通过 |
| 公历运算 | 完整 400 年周期，146097 个日期逐日验证 |
| 忙闲区间 | 200 组合成日程，与 90 天逐日占用模型比较 |
| 真实 CLI | 每后端 10 个进程用例，同时检查输出和退出码 |
| 稀疏规则 | 指定用例访问 37 个候选，而非逐日扫描的 366001 个；不是耗时倍数 |

输入、版本、复现方法、旧版本对照和局限均在 [维护验证记录](docs/QUALITY.md)。
四目标 CI 对 `wasm-gc / wasm / js / native` 分别执行检查、构建、测试、对照与 CLI。
同一输入在四个后端执行不算四个不同用例。没有声称完整 RFC 一致性或全路径覆盖率。

## 获取和验证

本次维护版本为 `0.2.1`，以 GitHub 源码和同名 Release 为交付依据；本轮未执行
MoonCakes 发布，不把 GitHub 更新等同于包仓库已同步。

```sh
git clone https://github.com/shangwuxi/moonrecur.git
cd moonrecur
moon update
moon fmt --check
moon check --target wasm-gc --deny-warn
moon build --target wasm-gc --deny-warn
moon test --target wasm-gc --deny-warn
python -m pip install -r scripts/requirements-test.txt
python scripts/compare_dateutil.py --target wasm-gc
python scripts/check_cli.py --target wasm-gc
```

本地验证使用 moon 0.1.20260904 / moonc v0.10.12。CI 安装工具链并记录版本；
较早工具链的格式化规则可能不同。native 执行还需要 C 编译器，本机只做 native
检查，native 构建与执行由 Ubuntu CI 完成。Python 仅用于对照验证，不是库运行依赖。

## 三个可复现的使用场景

### 1. 月底提醒：不存在的日期应跳过，而非顺延

提醒工具以 2024-01-31 为起点，展开三次月度提醒：

```sh
moon run cmd/moonrecur --target js -- expand --start 2024-01-31 --rule 'FREQ=MONTHLY;COUNT=3' --from 2024-01-01 --through 2024-06-30
```

```text
occurrences: 3
2024-01-31
2024-03-31
2024-05-31
```

想要“每月最后一天”应明确使用 `BYMONTHDAY=-1`，两种业务含义不同。

### 2. 提醒预览：排除两天后仍返回下一批有效日期

预览程序查询前两条有效提醒。COUNT=5 限制的是原始五次发生，不是五次保留结果：

```sh
moon run cmd/moonrecur --target js -- expand --start 2026-01-01 --rule 'FREQ=DAILY;COUNT=5' --from 2026-01-01 --through 2026-01-10 --limit 2 --exdate 2026-01-01 --exdate 2026-01-02
```

```text
occurrences: 2
2026-01-03
2026-01-04
```

如 COUNT=2，以上两个日期被排除后应为空；不能擅自增加原规则的发生次数。

### 3. 预约排期：发现冲突，再找窗口内空闲日期

排期工具接收带标签的全天区间。端点是闭区间，共用一天就构成冲突：

```sh
moon run cmd/moonrecur --target js -- conflicts --busy 'release:2026-08-10..2026-08-12' --busy 'review:2026-08-12..2026-08-13' --busy 'travel:2026-08-20..2026-08-21'
```

```text
conflicts: 1
release <> review:2026-08-12..2026-08-12
```

```sh
moon run cmd/moonrecur --target js -- free --from 2026-08-01 --through 2026-08-10 --busy 'before:2026-07-20..2026-08-02' --busy 'middle:2026-08-05..2026-08-06' --busy 'after:2026-08-10..2026-08-20'
```

```text
free: 2
2026-08-03..2026-08-04
2026-08-07..2026-08-09
```

上述结果均由 `scripts/check_cli.py` 通过真实进程核对，而非仅展示手写输出。

## 库调用

调用方在 `moon.pkg` 中导入 `shangwuxi/moonrecur`，别名为 `moonrecur`：

```moonbit
let start = @moonrecur.Date::parse("2026-08-03").unwrap()
let rule = @moonrecur.Rule::parse("FREQ=WEEKLY;COUNT=4;BYDAY=MO,WE").unwrap()
let window = @moonrecur.ExpansionWindow::make(
  @moonrecur.Date::parse("2026-08-01").unwrap(),
  @moonrecur.Date::parse("2026-08-31").unwrap(),
  100,
).unwrap()
let dates = @moonrecur.expand(start, rule, window).unwrap()
println(@moonrecur.dates_to_lines(dates))
```

用户输入应处理 `Result` 中的 Diagnostic，不建议直接 `unwrap()`。公开接口在
[`pkg.generated.mbti`](pkg.generated.mbti)；错误码在相关测试中断言。

## 边界与资料

- 公历年份 1–9999；DAILY/WEEKLY/MONTHLY/YEARLY 和明确列出的选择器。
- 规则文本最多 8192 UTF-16 单元，结果 limit 为 1–100000，每组例外最多 100000 条。
- 从 DTSTART 到查询终点最多相差 366000 天，即使 limit 很小也保留这个安全边界。
- 不做小时/分钟、DST、TZID、完整 iCalendar/CalDAV、序数星期或 BYSETPOS。
- 冲突接口返回所有源区间对，最坏输出仍为二次规模；调用者需控制输入数量。

[架构与不变量](docs/ARCHITECTURE.md) · [维护范围](docs/PROJECT_SCOPE.md) ·
[变更记录](CHANGELOG.md) · [安全边界](SECURITY.md) · [第三方说明](THIRD_PARTY.md) ·
[贡献指南](CONTRIBUTING.md) · [辅助工具使用披露](AI_USAGE.md)

## 许可证

Apache-2.0，见 [LICENSE](LICENSE)。实现为原创；python-dateutil 仅作为测试对照工具。
